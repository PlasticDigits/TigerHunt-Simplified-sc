// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdUint16} from "../datastore/DatastoreSetUint16.sol";
import {DatastoreSetIdUint48} from "../datastore/DatastoreSetUint48.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {EntityLib} from "../lib/EntityLib.sol";
import {ComponentLib} from "../lib/ComponentLib.sol";

/**
 * @title SystemEntityComponent
 * @dev Manages the bindings between entities and components in the ECS system
 * @notice Uses AccessManaged to restrict state-changing operations to authorized users
 * @notice Provides bidirectional lookups: entity->components and component->entities
 */
contract SystemEntityComponent is AccessManaged {
    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;

    // Events
    event ComponentAddedToEntity(EntityLib.EntityId indexed entityId, ComponentLib.ComponentId indexed componentId);
    event ComponentRemovedFromEntity(EntityLib.EntityId indexed entityId, ComponentLib.ComponentId indexed componentId);
    event EntityComponentsCleared(EntityLib.EntityId indexed entityId);

    // Errors
    error SystemEntityComponent_ComponentAlreadyAdded();
    error SystemEntityComponent_ComponentNotFound();

    constructor(DatastoreSetWrapper datastoreSetWrapper, address accessAuthority) AccessManaged(accessAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
    }

    /**
     * @dev Adds a component to an entity
     * @param entityId The entity to add the component to
     * @param componentId The component to add
     */
    function addComponent(EntityLib.EntityId entityId, ComponentLib.ComponentId componentId) external restricted {
        DatastoreSetIdUint16 entityComponentSetId = EntityLib.getEntityComponentSetKey(entityId);
        DatastoreSetIdUint48 componentEntitySetId = ComponentLib.getComponentEntitySetKey(componentId);

        // Check if component is already added to entity
        require(
            !DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().contains(
                address(this), entityComponentSetId, ComponentLib.ComponentId.unwrap(componentId)
            ),
            SystemEntityComponent_ComponentAlreadyAdded()
        );

        // Add component to entity's component set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().add(
            entityComponentSetId, ComponentLib.ComponentId.unwrap(componentId)
        );

        // Add entity to component's entity set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().add(componentEntitySetId, EntityLib.EntityId.unwrap(entityId));

        emit ComponentAddedToEntity(entityId, componentId);
    }

    /**
     * @dev Removes a component from an entity
     * @param entityId The entity to remove the component from
     * @param componentId The component to remove
     */
    function removeComponent(EntityLib.EntityId entityId, ComponentLib.ComponentId componentId) external restricted {
        DatastoreSetIdUint16 entityComponentSetId = EntityLib.getEntityComponentSetKey(entityId);
        DatastoreSetIdUint48 componentEntitySetId = ComponentLib.getComponentEntitySetKey(componentId);

        // Check if component exists on entity
        require(
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().contains(
                address(this), entityComponentSetId, ComponentLib.ComponentId.unwrap(componentId)
            ),
            SystemEntityComponent_ComponentNotFound()
        );

        // Remove component from entity's component set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().remove(
            entityComponentSetId, ComponentLib.ComponentId.unwrap(componentId)
        );

        // Remove entity from component's entity set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().remove(componentEntitySetId, EntityLib.EntityId.unwrap(entityId));

        emit ComponentRemovedFromEntity(entityId, componentId);
    }

    /**
     * @dev Adds multiple components to an entity in batch
     * @param entityId The entity to add components to
     * @param componentIds Array of components to add
     */
    function addComponentsBatch(EntityLib.EntityId entityId, ComponentLib.ComponentId[] calldata componentIds)
        external
        restricted
    {
        DatastoreSetIdUint16 entityComponentSetId = EntityLib.getEntityComponentSetKey(entityId);

        // Convert ComponentIds to uint16 array and validate
        uint16[] memory componentUint16s = new uint16[](componentIds.length);
        uint48[] memory entityUint48s = new uint48[](componentIds.length);

        for (uint256 i = 0; i < componentIds.length; i++) {
            uint16 componentIdUint16 = ComponentLib.ComponentId.unwrap(componentIds[i]);

            // Check if component is already added to entity
            require(
                !DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().contains(
                    address(this), entityComponentSetId, componentIdUint16
                ),
                SystemEntityComponent_ComponentAlreadyAdded()
            );

            componentUint16s[i] = componentIdUint16;
            entityUint48s[i] = EntityLib.EntityId.unwrap(entityId);
        }

        // Add components to entity's component set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().addBatch(entityComponentSetId, componentUint16s);

        // Add entity to each component's entity set
        for (uint256 i = 0; i < componentIds.length; i++) {
            DatastoreSetIdUint48 componentEntitySetId = ComponentLib.getComponentEntitySetKey(componentIds[i]);
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().add(componentEntitySetId, EntityLib.EntityId.unwrap(entityId));

            emit ComponentAddedToEntity(entityId, componentIds[i]);
        }
    }

    /**
     * @dev Removes multiple components from an entity in batch
     * @param entityId The entity to remove components from
     * @param componentIds Array of components to remove
     */
    function removeComponentsBatch(EntityLib.EntityId entityId, ComponentLib.ComponentId[] calldata componentIds)
        external
        restricted
    {
        DatastoreSetIdUint16 entityComponentSetId = EntityLib.getEntityComponentSetKey(entityId);

        // Convert ComponentIds to uint16 array and validate
        uint16[] memory componentUint16s = new uint16[](componentIds.length);

        for (uint256 i = 0; i < componentIds.length; i++) {
            uint16 componentIdUint16 = ComponentLib.ComponentId.unwrap(componentIds[i]);

            // Check if component exists on entity
            require(
                !DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().contains(
                    address(this), entityComponentSetId, componentIdUint16
                ),
                SystemEntityComponent_ComponentNotFound()
            );

            componentUint16s[i] = componentIdUint16;
        }

        // Remove components from entity's component set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().removeBatch(entityComponentSetId, componentUint16s);

        // Remove entity from each component's entity set
        for (uint256 i = 0; i < componentIds.length; i++) {
            DatastoreSetIdUint48 componentEntitySetId = ComponentLib.getComponentEntitySetKey(componentIds[i]);
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().remove(
                componentEntitySetId, EntityLib.EntityId.unwrap(entityId)
            );

            emit ComponentRemovedFromEntity(entityId, componentIds[i]);
        }
    }

    /**
     * @dev Clears all components from an entity (used when despawning)
     * @param entityId The entity to clear components from
     */
    function clearEntityComponents(EntityLib.EntityId entityId) external restricted {
        DatastoreSetIdUint16 entityComponentSetId = EntityLib.getEntityComponentSetKey(entityId);

        // Get all components for this entity
        uint16[] memory componentUint16s =
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().getAll(address(this), entityComponentSetId);

        if (componentUint16s.length == 0) {
            return; // No components to clear
        }

        // Remove entity from each component's entity set
        for (uint256 i = 0; i < componentUint16s.length; i++) {
            ComponentLib.ComponentId componentId = ComponentLib.ComponentId.wrap(componentUint16s[i]);
            DatastoreSetIdUint48 componentEntitySetId = ComponentLib.getComponentEntitySetKey(componentId);
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().remove(
                componentEntitySetId, EntityLib.EntityId.unwrap(entityId)
            );
        }

        // Remove all components from entity's component set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().removeBatch(entityComponentSetId, componentUint16s);

        emit EntityComponentsCleared(entityId);
    }

    // View functions

    /**
     * @dev Checks if an entity has a specific component
     * @param entityId The entity to check
     * @param componentId The component to check for
     * @return True if the entity has the component
     */
    function hasComponent(EntityLib.EntityId entityId, ComponentLib.ComponentId componentId)
        external
        view
        returns (bool)
    {
        DatastoreSetIdUint16 entityComponentSetId = EntityLib.getEntityComponentSetKey(entityId);
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().contains(
            address(this), entityComponentSetId, ComponentLib.ComponentId.unwrap(componentId)
        );
    }

    /**
     * @dev Returns all component IDs for an entity
     * @param entityId The entity to get components for
     * @return componentIds Array of component IDs
     */
    function getEntityComponents(EntityLib.EntityId entityId)
        external
        view
        returns (ComponentLib.ComponentId[] memory componentIds)
    {
        DatastoreSetIdUint16 entityComponentSetId = EntityLib.getEntityComponentSetKey(entityId);
        uint16[] memory componentUint16s =
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().getAll(address(this), entityComponentSetId);

        componentIds = new ComponentLib.ComponentId[](componentUint16s.length);
        for (uint256 i = 0; i < componentUint16s.length; i++) {
            componentIds[i] = ComponentLib.ComponentId.wrap(componentUint16s[i]);
        }

        return componentIds;
    }

    /**
     * @dev Returns all entity IDs that have a specific component
     * @param componentId The component to get entities for
     * @return entityIds Array of entity IDs
     */
    function getComponentEntities(ComponentLib.ComponentId componentId)
        external
        view
        returns (EntityLib.EntityId[] memory entityIds)
    {
        DatastoreSetIdUint48 componentEntitySetId = ComponentLib.getComponentEntitySetKey(componentId);
        uint48[] memory entityUint48s =
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().getAll(address(this), componentEntitySetId);

        entityIds = new EntityLib.EntityId[](entityUint48s.length);
        for (uint256 i = 0; i < entityUint48s.length; i++) {
            entityIds[i] = EntityLib.EntityId.wrap(entityUint48s[i]);
        }

        return entityIds;
    }

    /**
     * @dev Returns the number of components an entity has
     * @param entityId The entity to count components for
     * @return count The number of components
     */
    function getEntityComponentCount(EntityLib.EntityId entityId) external view returns (uint256 count) {
        DatastoreSetIdUint16 entityComponentSetId = EntityLib.getEntityComponentSetKey(entityId);
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT16().length(address(this), entityComponentSetId);
    }

    /**
     * @dev Returns the number of entities that have a specific component
     * @param componentId The component to count entities for
     * @return count The number of entities
     */
    function getComponentEntityCount(ComponentLib.ComponentId componentId) external view returns (uint256 count) {
        DatastoreSetIdUint48 componentEntitySetId = ComponentLib.getComponentEntitySetKey(componentId);
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().length(address(this), componentEntitySetId);
    }
}
