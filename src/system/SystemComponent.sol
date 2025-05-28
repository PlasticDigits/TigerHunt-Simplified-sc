// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdComponent} from "../datastore/DatastoreSetComponent.sol";
import {DatastoreSetIdComponentField} from "../datastore/DatastoreSetComponentField.sol";
import {SystemComponentField} from "./SystemComponentField.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ComponentLib} from "../lib/ComponentLib.sol";

/**
 * @title SystemComponent
 * @dev Manages the creation, updating, and removal of components in the ECS system
 * @notice Uses AccessManaged to restrict state-changing operations to authorized users
 * @notice Uses SystemComponentField for field management and DatastoreSetComponentField for field associations
 */
contract SystemComponent is AccessManaged {
    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;
    SystemComponentField public immutable SYSTEM_COMPONENT_FIELD;

    // Component registry key
    bytes32 public constant COMPONENT_REGISTRY_KEY = keccak256("COMPONENT_REGISTRY");

    // Component data storage
    mapping(ComponentLib.ComponentId id => ComponentData data) private _components;

    // Nonce for generating new component IDs
    uint16 private _nonce;

    struct ComponentData {
        string name;
        string description;
        bool exists;
    }

    // Errors
    error SystemComponent_ComponentNotFound();
    error SystemComponent_ComponentAlreadyExists();
    error SystemComponent_FieldNotFound();
    error SystemComponent_FieldAlreadyExists();

    constructor(
        DatastoreSetWrapper datastoreSetWrapper,
        SystemComponentField systemComponentField,
        address accessAuthority
    ) AccessManaged(accessAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
        SYSTEM_COMPONENT_FIELD = systemComponentField;
        _nonce = 0;
    }

    /**
     * @dev Creates a new component with the given name and description
     * @param componentId The unique identifier for the component (0 to auto-generate)
     * @param name The human-readable name of the component
     * @param description The description of what this component represents
     */
    function create(ComponentLib.ComponentId componentId, string calldata name, string calldata description)
        external
        restricted
    {
        ComponentLib.ComponentId newComponentId = componentId;

        // Generate ID if not provided
        if (ComponentLib.ComponentId.unwrap(componentId) == 0) {
            newComponentId = _generateComponentId();
        }

        if (_components[newComponentId].exists) {
            revert SystemComponent_ComponentAlreadyExists();
        }

        _components[newComponentId] = ComponentData({name: name, description: description, exists: true});

        // Add component to the registry set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT().add(getComponentRegistrySetId(), newComponentId);
    }

    /**
     * @dev Updates an existing component's name and description
     * @param componentId The component identifier to update
     * @param name The new name for the component
     * @param description The new description for the component
     */
    function update(ComponentLib.ComponentId componentId, string calldata name, string calldata description)
        external
        restricted
    {
        if (!_components[componentId].exists) {
            revert SystemComponent_ComponentNotFound();
        }

        _components[componentId].name = name;
        _components[componentId].description = description;
    }

    /**
     * @dev Removes a component from the system
     * @param componentId The component identifier to remove
     */
    function remove(ComponentLib.ComponentId componentId) external restricted {
        if (!_components[componentId].exists) {
            revert SystemComponent_ComponentNotFound();
        }

        // Remove component from the registry set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT().remove(getComponentRegistrySetId(), componentId);

        // Clean up component data
        delete _components[componentId];
    }

    /**
     * @dev Adds a field to an existing component
     * @param componentId The component to add the field to
     * @param fieldId The field identifier to add
     */
    function addField(ComponentLib.ComponentId componentId, ComponentLib.ComponentFieldId fieldId)
        external
        restricted
    {
        if (!_components[componentId].exists) {
            revert SystemComponent_ComponentNotFound();
        }

        if (!SYSTEM_COMPONENT_FIELD.exists(fieldId)) {
            revert SystemComponent_FieldNotFound();
        }

        DatastoreSetIdComponentField componentFieldSetId = getComponentFieldSetId(componentId);

        if (DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(address(this), componentFieldSetId, fieldId))
        {
            revert SystemComponent_FieldAlreadyExists();
        }

        DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().add(componentFieldSetId, fieldId);
    }

    /**
     * @dev Removes a field from a component
     * @param componentId The component to remove the field from
     * @param fieldId The field identifier to remove
     */
    function removeField(ComponentLib.ComponentId componentId, ComponentLib.ComponentFieldId fieldId)
        external
        restricted
    {
        DatastoreSetIdComponentField componentFieldSetId = getComponentFieldSetId(componentId);
        DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().remove(componentFieldSetId, fieldId);
    }

    /**
     * @dev Batch adds multiple fields to a component
     * @param componentId The component to add fields to
     * @param fieldIds Array of field identifiers to add
     */
    function addFieldsBatch(ComponentLib.ComponentId componentId, ComponentLib.ComponentFieldId[] calldata fieldIds)
        external
        restricted
    {
        if (!_components[componentId].exists) {
            revert SystemComponent_ComponentNotFound();
        }

        // Verify all fields exist and are not already added
        DatastoreSetIdComponentField componentFieldSetId = getComponentFieldSetId(componentId);
        for (uint256 i = 0; i < fieldIds.length; i++) {
            if (!SYSTEM_COMPONENT_FIELD.exists(fieldIds[i])) {
                revert SystemComponent_FieldNotFound();
            }

            if (
                DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(
                    address(this), componentFieldSetId, fieldIds[i]
                )
            ) {
                revert SystemComponent_FieldAlreadyExists();
            }
        }

        DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().addBatch(componentFieldSetId, fieldIds);
    }

    /**
     * @dev Batch removes multiple fields from a component
     * @param componentId The component to remove fields from
     * @param fieldIds Array of field identifiers to remove
     */
    function removeFieldsBatch(ComponentLib.ComponentId componentId, ComponentLib.ComponentFieldId[] calldata fieldIds)
        external
        restricted
    {
        DatastoreSetIdComponentField componentFieldSetId = getComponentFieldSetId(componentId);
        DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().removeBatch(componentFieldSetId, fieldIds);
    }

    /**
     * @dev Generates a new unique component ID using nonce
     * @return componentId The generated component ID
     */
    function _generateComponentId() private returns (ComponentLib.ComponentId componentId) {
        do {
            componentId = ComponentLib.ComponentId.wrap(_nonce);
            _nonce++;
        } while (_components[componentId].exists);

        return componentId;
    }

    // View functions

    /**
     * @dev Returns the component registry set identifier
     */
    function getComponentRegistrySetId() public pure returns (DatastoreSetIdComponent) {
        return DatastoreSetIdComponent.wrap(COMPONENT_REGISTRY_KEY);
    }

    /**
     * @dev Returns the component field set identifier for a specific component
     * @param componentId The component identifier
     */
    function getComponentFieldSetId(ComponentLib.ComponentId componentId)
        public
        pure
        returns (DatastoreSetIdComponentField)
    {
        return DatastoreSetIdComponentField.wrap(keccak256(abi.encodePacked("COMPONENT_FIELD_SET", componentId)));
    }

    /**
     * @dev Checks if a component exists
     * @param componentId The component identifier to check
     * @return True if the component exists
     */
    function exists(ComponentLib.ComponentId componentId) external view returns (bool) {
        return _components[componentId].exists;
    }

    /**
     * @dev Returns component information
     * @param componentId The component identifier
     * @return name The component name
     * @return description The component description
     * @return fieldCount The number of fields in the component
     */
    function get(ComponentLib.ComponentId componentId)
        external
        view
        returns (string memory name, string memory description, uint256 fieldCount)
    {
        if (!_components[componentId].exists) {
            revert SystemComponent_ComponentNotFound();
        }

        ComponentData storage component = _components[componentId];
        DatastoreSetIdComponentField componentFieldSetId = getComponentFieldSetId(componentId);
        uint256 count = DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().length(address(this), componentFieldSetId);

        return (component.name, component.description, count);
    }

    /**
     * @dev Returns a component field definition
     * @param componentId The component identifier
     * @param fieldId The field identifier
     * @return field The field definition
     */
    function getField(ComponentLib.ComponentId componentId, ComponentLib.ComponentFieldId fieldId)
        external
        view
        returns (ComponentLib.ComponentField memory field)
    {
        if (!_components[componentId].exists) {
            revert SystemComponent_ComponentNotFound();
        }

        DatastoreSetIdComponentField componentFieldSetId = getComponentFieldSetId(componentId);
        if (
            !DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(address(this), componentFieldSetId, fieldId)
        ) {
            revert SystemComponent_FieldNotFound();
        }

        return SYSTEM_COMPONENT_FIELD.get(fieldId);
    }

    /**
     * @dev Returns all field IDs for a specific component
     * @param componentId The component identifier
     * @return fieldIds Array of component field identifiers for the component
     */
    function getFieldIds(ComponentLib.ComponentId componentId)
        external
        view
        returns (ComponentLib.ComponentFieldId[] memory fieldIds)
    {
        if (!_components[componentId].exists) {
            revert SystemComponent_ComponentNotFound();
        }

        DatastoreSetIdComponentField componentFieldSetId = getComponentFieldSetId(componentId);
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().getAll(address(this), componentFieldSetId);
    }

    /**
     * @dev Returns all fields for a specific component
     * @param componentId The component identifier
     * @return fields Array of component field definitions for the component
     */
    function getFields(ComponentLib.ComponentId componentId)
        external
        view
        returns (ComponentLib.ComponentField[] memory fields)
    {
        if (!_components[componentId].exists) {
            revert SystemComponent_ComponentNotFound();
        }

        DatastoreSetIdComponentField componentFieldSetId = getComponentFieldSetId(componentId);
        ComponentLib.ComponentFieldId[] memory fieldIds =
            DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().getAll(address(this), componentFieldSetId);

        fields = new ComponentLib.ComponentField[](fieldIds.length);
        for (uint256 i = 0; i < fieldIds.length; i++) {
            fields[i] = SYSTEM_COMPONENT_FIELD.get(fieldIds[i]);
        }

        return fields;
    }

    /**
     * @dev Checks if a component has a specific field
     * @param componentId The component identifier
     * @param fieldId The field identifier
     * @return True if the component has the field
     */
    function hasField(ComponentLib.ComponentId componentId, ComponentLib.ComponentFieldId fieldId)
        external
        view
        returns (bool)
    {
        if (!_components[componentId].exists) {
            return false;
        }

        DatastoreSetIdComponentField componentFieldSetId = getComponentFieldSetId(componentId);
        return
            DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(address(this), componentFieldSetId, fieldId);
    }

    /**
     * @dev Returns all registered component IDs
     * @return componentIds Array of all component identifiers
     */
    function getAll() external view returns (ComponentLib.ComponentId[] memory componentIds) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT().getAll(address(this), getComponentRegistrySetId());
    }

    /**
     * @dev Returns the total number of registered components
     * @return count The number of components
     */
    function getCount() external view returns (uint256 count) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT().length(address(this), getComponentRegistrySetId());
    }

    /**
     * @dev Returns the current nonce value
     * @return nonce The current nonce
     */
    function getNonce() external view returns (uint16 nonce) {
        return _nonce;
    }
}
