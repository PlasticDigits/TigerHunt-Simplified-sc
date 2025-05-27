// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {EntityLib} from "../lib/EntityLib.sol";
import {IComponent} from "../component/IComponent.sol";
import {IComponentRegistry} from "../component/IComponentRegistry.sol";

/**
 * @title SystemComponent
 * @dev System for managing components on entities in the ECS architecture
 * @notice This contract handles adding and removing components from entities with access control
 */
contract SystemComponent is AccessManaged, IComponentRegistry {
    using EntityLib for EntityLib.EntityId;

    // Storage
    mapping(bytes32 => IComponent) private _components;
    mapping(EntityLib.EntityId => mapping(bytes32 => bool)) private _entityComponents;
    mapping(EntityLib.EntityId => bytes32[]) private _entityComponentList;
    bytes32[] private _registeredComponentTypes;
    mapping(bytes32 => bool) private _isComponentTypeRegistered;

    // Events
    event ComponentAddedToEntity(EntityLib.EntityId indexed entityId, bytes32 indexed componentType);
    event ComponentRemovedFromEntity(EntityLib.EntityId indexed entityId, bytes32 indexed componentType);

    // Errors
    error ComponentNotRegistered(bytes32 componentType);
    error ComponentAlreadyRegistered(bytes32 componentType);
    error EntityDoesNotHaveComponent(EntityLib.EntityId entityId, bytes32 componentType);
    error EntityAlreadyHasComponent(EntityLib.EntityId entityId, bytes32 componentType);
    error InvalidComponent();

    /**
     * @dev Constructor
     * @param initialAuthority The initial authority for access management
     */
    constructor(address initialAuthority) AccessManaged(initialAuthority) {}

    /**
     * @inheritdoc IComponentRegistry
     */
    function registerComponent(IComponent component) external restricted {
        if (address(component) == address(0)) revert InvalidComponent();

        bytes32 componentType = component.getComponentType();
        if (_isComponentTypeRegistered[componentType]) {
            revert ComponentAlreadyRegistered(componentType);
        }

        _components[componentType] = component;
        _registeredComponentTypes.push(componentType);
        _isComponentTypeRegistered[componentType] = true;

        emit ComponentRegistered(componentType, address(component));
    }

    /**
     * @inheritdoc IComponentRegistry
     */
    function unregisterComponent(bytes32 componentType) external restricted {
        if (!_isComponentTypeRegistered[componentType]) {
            revert ComponentNotRegistered(componentType);
        }

        delete _components[componentType];
        _isComponentTypeRegistered[componentType] = false;

        // Remove from registered types array
        for (uint256 i = 0; i < _registeredComponentTypes.length; i++) {
            if (_registeredComponentTypes[i] == componentType) {
                _registeredComponentTypes[i] = _registeredComponentTypes[_registeredComponentTypes.length - 1];
                _registeredComponentTypes.pop();
                break;
            }
        }

        emit ComponentUnregistered(componentType);
    }

    /**
     * @dev Adds a component to an entity
     * @param entityId The entity to add the component to
     * @param componentType The type of component to add
     */
    function addComponent(EntityLib.EntityId entityId, bytes32 componentType) external restricted {
        if (!_isComponentTypeRegistered[componentType]) {
            revert ComponentNotRegistered(componentType);
        }

        if (_entityComponents[entityId][componentType]) {
            revert EntityAlreadyHasComponent(entityId, componentType);
        }

        _entityComponents[entityId][componentType] = true;
        _entityComponentList[entityId].push(componentType);

        emit ComponentAddedToEntity(entityId, componentType);
    }

    /**
     * @dev Removes a component from an entity
     * @param entityId The entity to remove the component from
     * @param componentType The type of component to remove
     */
    function removeComponent(EntityLib.EntityId entityId, bytes32 componentType) external restricted {
        if (!_entityComponents[entityId][componentType]) {
            revert EntityDoesNotHaveComponent(entityId, componentType);
        }

        _entityComponents[entityId][componentType] = false;

        // Remove from entity component list
        bytes32[] storage componentList = _entityComponentList[entityId];
        for (uint256 i = 0; i < componentList.length; i++) {
            if (componentList[i] == componentType) {
                componentList[i] = componentList[componentList.length - 1];
                componentList.pop();
                break;
            }
        }

        // Call the component's remove function if it exists
        IComponent component = _components[componentType];
        if (address(component) != address(0)) {
            component.removeComponent(entityId);
        }

        emit ComponentRemovedFromEntity(entityId, componentType);
    }

    /**
     * @dev Removes all components from an entity
     * @param entityId The entity to remove all components from
     */
    function removeAllComponents(EntityLib.EntityId entityId) external restricted {
        bytes32[] memory componentTypes = _entityComponentList[entityId];

        for (uint256 i = 0; i < componentTypes.length; i++) {
            bytes32 componentType = componentTypes[i];
            _entityComponents[entityId][componentType] = false;

            // Call the component's remove function if it exists
            IComponent component = _components[componentType];
            if (address(component) != address(0)) {
                component.removeComponent(entityId);
            }

            emit ComponentRemovedFromEntity(entityId, componentType);
        }

        // Clear the component list
        delete _entityComponentList[entityId];
    }

    /**
     * @inheritdoc IComponentRegistry
     */
    function getComponent(bytes32 componentType) external view returns (IComponent) {
        return _components[componentType];
    }

    /**
     * @inheritdoc IComponentRegistry
     */
    function isComponentRegistered(bytes32 componentType) external view returns (bool) {
        return _isComponentTypeRegistered[componentType];
    }

    /**
     * @inheritdoc IComponentRegistry
     */
    function getRegisteredComponentTypes() external view returns (bytes32[] memory) {
        return _registeredComponentTypes;
    }

    /**
     * @dev Checks if an entity has a specific component
     * @param entityId The entity to check
     * @param componentType The component type to check for
     * @return True if the entity has the component
     */
    function hasComponent(EntityLib.EntityId entityId, bytes32 componentType) external view returns (bool) {
        return _entityComponents[entityId][componentType];
    }

    /**
     * @dev Gets all component types for an entity
     * @param entityId The entity to get components for
     * @return Array of component types the entity has
     */
    function getEntityComponents(EntityLib.EntityId entityId) external view returns (bytes32[] memory) {
        return _entityComponentList[entityId];
    }

    /**
     * @dev Gets the number of components an entity has
     * @param entityId The entity to count components for
     * @return The number of components
     */
    function getEntityComponentCount(EntityLib.EntityId entityId) external view returns (uint256) {
        return _entityComponentList[entityId].length;
    }

    /**
     * @dev Checks if an entity has all specified components
     * @param entityId The entity to check
     * @param componentTypes Array of component types to check for
     * @return True if the entity has all specified components
     */
    function hasAllComponents(EntityLib.EntityId entityId, bytes32[] calldata componentTypes)
        external
        view
        returns (bool)
    {
        for (uint256 i = 0; i < componentTypes.length; i++) {
            if (!_entityComponents[entityId][componentTypes[i]]) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Checks if an entity has any of the specified components
     * @param entityId The entity to check
     * @param componentTypes Array of component types to check for
     * @return True if the entity has any of the specified components
     */
    function hasAnyComponent(EntityLib.EntityId entityId, bytes32[] calldata componentTypes)
        external
        view
        returns (bool)
    {
        for (uint256 i = 0; i < componentTypes.length; i++) {
            if (_entityComponents[entityId][componentTypes[i]]) {
                return true;
            }
        }
        return false;
    }
}
