// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {EntityLib} from "../lib/EntityLib.sol";
import {
    ComponentData,
    ComponentSchema,
    ComponentValue,
    ComponentField,
    ComponentDataType,
    ComponentId,
    IComponentDataEvents
} from "../component/ComponentData.sol";
import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdUint48} from "../datastore/DatastoreSetUint48.sol";
import {DatastoreSetIdUint16} from "../datastore/DatastoreSetUint16.sol";

/**
 * @title SystemComponentV2
 * @dev New ECS component system using struct-based components and efficient datastore
 * @notice Components are pure data structures stored in mappings, entity-component relationships tracked in datastores
 */
contract SystemComponentV2 is AccessManaged, IComponentDataEvents {
    using EntityLib for EntityLib.EntityId;

    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;

    // Partial keys for datastore sets
    bytes32 public constant ENTITY_COMPONENTS_KEY_PARTIAL = keccak256("ENTITY_COMPONENTS_KEY_PARTIAL");
    bytes32 public constant COMPONENT_ENTITIES_KEY_PARTIAL = keccak256("COMPONENT_ENTITIES_KEY_PARTIAL");

    // Component schemas registry
    mapping(ComponentId => ComponentSchema) private _componentSchemas;
    ComponentId[] private _registeredComponentIds;
    mapping(ComponentId => bool) private _isComponentIdRegistered;

    // Component data storage: entityId => componentId => ComponentData
    mapping(EntityLib.EntityId => mapping(ComponentId => ComponentData)) private _entityComponentData;

    // Track which entities have which components for efficient queries
    mapping(EntityLib.EntityId => ComponentId[]) private _entityComponentsList;
    mapping(ComponentId => EntityLib.EntityId[]) private _componentEntitiesList;

    // Errors
    error ComponentNotRegistered(ComponentId componentId);
    error ComponentAlreadyRegistered(ComponentId componentId);
    error EntityDoesNotHaveComponent(EntityLib.EntityId entityId, ComponentId componentId);
    error EntityAlreadyHasComponent(EntityLib.EntityId entityId, ComponentId componentId);
    error InvalidComponentSchema();
    error InvalidFieldName(string fieldName);
    error InvalidDataType(ComponentDataType expected, ComponentDataType provided);
    error RequiredFieldMissing(string fieldName);

    /**
     * @dev Constructor
     * @param datastoreSetWrapper The datastore wrapper for efficient set operations
     * @param initialAuthority The initial authority for access management
     */
    constructor(DatastoreSetWrapper datastoreSetWrapper, address initialAuthority) AccessManaged(initialAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
    }

    /**
     * @dev Registers a new component schema
     * @param schema The component schema to register
     */
    function registerComponentSchema(ComponentSchema calldata schema) external restricted {
        if (schema.fields.length == 0) revert InvalidComponentSchema();
        if (_isComponentIdRegistered[schema.id]) revert ComponentAlreadyRegistered(schema.id);

        // Store the schema (note: we need to manually copy arrays in storage)
        ComponentSchema storage newSchema = _componentSchemas[schema.id];
        newSchema.id = schema.id;
        newSchema.name = schema.name;
        newSchema.description = schema.description;
        newSchema.isActive = true;

        // Copy fields array
        for (uint256 i = 0; i < schema.fields.length; i++) {
            newSchema.fields.push(schema.fields[i]);
        }

        _registeredComponentIds.push(schema.id);
        _isComponentIdRegistered[schema.id] = true;

        emit ComponentSchemaRegistered(schema.id, schema.name);
    }

    /**
     * @dev Updates an existing component schema
     * @param schema The updated component schema
     */
    function updateComponentSchema(ComponentSchema calldata schema) external restricted {
        if (!_isComponentIdRegistered[schema.id]) revert ComponentNotRegistered(schema.id);

        ComponentSchema storage existingSchema = _componentSchemas[schema.id];
        existingSchema.name = schema.name;
        existingSchema.description = schema.description;
        existingSchema.isActive = schema.isActive;

        // Clear existing fields and copy new ones
        delete existingSchema.fields;
        for (uint256 i = 0; i < schema.fields.length; i++) {
            existingSchema.fields.push(schema.fields[i]);
        }

        emit ComponentSchemaUpdated(schema.id, schema.name);
    }

    /**
     * @dev Adds a component to an entity
     * @param entityId The entity to add the component to
     * @param componentId The component type to add
     */
    function addComponent(EntityLib.EntityId entityId, ComponentId componentId) external restricted {
        if (!_isComponentIdRegistered[componentId]) revert ComponentNotRegistered(componentId);
        if (hasComponent(entityId, componentId)) revert EntityAlreadyHasComponent(entityId, componentId);

        // Add to efficient datastore sets
        DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().add(
            getEntityComponentsSetKey(entityId), uint48(ComponentId.unwrap(componentId))
        );

        DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().add(
            getComponentEntitiesSetKey(componentId), EntityLib.EntityId.unwrap(entityId)
        );

        // Initialize component data
        ComponentData storage compData = _entityComponentData[entityId][componentId];
        compData.componentId = componentId;

        emit ComponentAddedToEntity(entityId, componentId);
    }

    /**
     * @dev Removes a component from an entity
     * @param entityId The entity to remove the component from
     * @param componentId The component type to remove
     */
    function removeComponent(EntityLib.EntityId entityId, ComponentId componentId) external restricted {
        if (!hasComponent(entityId, componentId)) revert EntityDoesNotHaveComponent(entityId, componentId);

        // Remove from efficient datastore sets
        DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().remove(
            getEntityComponentsSetKey(entityId), uint48(ComponentId.unwrap(componentId))
        );

        DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().remove(
            getComponentEntitiesSetKey(componentId), EntityLib.EntityId.unwrap(entityId)
        );

        // Clear component data
        delete _entityComponentData[entityId][componentId];

        emit ComponentRemovedFromEntity(entityId, componentId);
    }

    /**
     * @dev Removes all components from an entity
     * @param entityId The entity to remove all components from
     */
    function removeAllComponents(EntityLib.EntityId entityId) external restricted {
        uint48[] memory componentIds =
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().getAll(address(this), getEntityComponentsSetKey(entityId));

        for (uint256 i = 0; i < componentIds.length; i++) {
            ComponentId componentId = ComponentId.wrap(uint16(componentIds[i]));

            // Remove from component entities set
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().remove(
                getComponentEntitiesSetKey(componentId), EntityLib.EntityId.unwrap(entityId)
            );

            // Clear component data
            delete _entityComponentData[entityId][componentId];

            emit ComponentRemovedFromEntity(entityId, componentId);
        }

        // Clear the entity's component set
        // Note: We can't easily clear the entire set, so we'll remove each item
        for (uint256 i = 0; i < componentIds.length; i++) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().remove(getEntityComponentsSetKey(entityId), componentIds[i]);
        }
    }

    /**
     * @dev Sets a field value for an entity's component
     * @param entityId The entity
     * @param componentId The component
     * @param fieldName The field name
     * @param value The value to set
     */
    function setComponentField(
        EntityLib.EntityId entityId,
        ComponentId componentId,
        string calldata fieldName,
        ComponentValue calldata value
    ) external restricted {
        if (!hasComponent(entityId, componentId)) revert EntityDoesNotHaveComponent(entityId, componentId);

        // Validate field exists in schema
        ComponentSchema storage schema = _componentSchemas[componentId];
        bool fieldExists = false;
        ComponentDataType expectedType;

        for (uint256 i = 0; i < schema.fields.length; i++) {
            if (keccak256(bytes(schema.fields[i].name)) == keccak256(bytes(fieldName))) {
                fieldExists = true;
                expectedType = schema.fields[i].dataType;
                break;
            }
        }

        if (!fieldExists) revert InvalidFieldName(fieldName);
        if (expectedType != value.dataType) revert InvalidDataType(expectedType, value.dataType);

        ComponentData storage compData = _entityComponentData[entityId][componentId];

        // Check if this is a new field
        bool isNewField = compData.fieldValues[fieldName].dataType == ComponentDataType.NONE;

        // Set the value
        compData.fieldValues[fieldName] = value;

        // Add to field names list if new
        if (isNewField) {
            compData.fieldNames.push(fieldName);
        }

        emit ComponentDataSet(entityId, componentId, fieldName, value.dataType);
    }

    /**
     * @dev Clears a field value for an entity's component
     * @param entityId The entity
     * @param componentId The component
     * @param fieldName The field name
     */
    function clearComponentField(EntityLib.EntityId entityId, ComponentId componentId, string calldata fieldName)
        external
        restricted
    {
        if (!hasComponent(entityId, componentId)) revert EntityDoesNotHaveComponent(entityId, componentId);

        ComponentData storage compData = _entityComponentData[entityId][componentId];
        delete compData.fieldValues[fieldName];

        // Remove from field names list
        for (uint256 i = 0; i < compData.fieldNames.length; i++) {
            if (keccak256(bytes(compData.fieldNames[i])) == keccak256(bytes(fieldName))) {
                compData.fieldNames[i] = compData.fieldNames[compData.fieldNames.length - 1];
                compData.fieldNames.pop();
                break;
            }
        }

        emit ComponentDataCleared(entityId, componentId, fieldName);
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Checks if an entity has a specific component
     * @param entityId The entity to check
     * @param componentId The component type to check for
     * @return True if the entity has the component
     */
    function hasComponent(EntityLib.EntityId entityId, ComponentId componentId) public view returns (bool) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().contains(
            address(this), getEntityComponentsSetKey(entityId), uint48(ComponentId.unwrap(componentId))
        );
    }

    /**
     * @dev Gets all component IDs for an entity
     * @param entityId The entity to get components for
     * @return Array of component IDs the entity has
     */
    function getEntityComponents(EntityLib.EntityId entityId) external view returns (ComponentId[] memory) {
        uint48[] memory componentIds =
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().getAll(address(this), getEntityComponentsSetKey(entityId));

        ComponentId[] memory result = new ComponentId[](componentIds.length);
        for (uint256 i = 0; i < componentIds.length; i++) {
            result[i] = ComponentId.wrap(uint16(componentIds[i]));
        }
        return result;
    }

    /**
     * @dev Gets all entities that have a specific component
     * @param componentId The component to search for
     * @return Array of entity IDs that have this component
     */
    function getEntitiesWithComponent(ComponentId componentId) external view returns (EntityLib.EntityId[] memory) {
        uint48[] memory entityIds =
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT48().getAll(address(this), getComponentEntitiesSetKey(componentId));

        EntityLib.EntityId[] memory result = new EntityLib.EntityId[](entityIds.length);
        for (uint256 i = 0; i < entityIds.length; i++) {
            result[i] = EntityLib.EntityId.wrap(entityIds[i]);
        }
        return result;
    }

    /**
     * @dev Gets component field value
     * @param entityId The entity
     * @param componentId The component
     * @param fieldName The field name
     * @return The field value
     */
    function getComponentField(EntityLib.EntityId entityId, ComponentId componentId, string calldata fieldName)
        external
        view
        returns (ComponentValue memory)
    {
        if (!hasComponent(entityId, componentId)) revert EntityDoesNotHaveComponent(entityId, componentId);
        return _entityComponentData[entityId][componentId].fieldValues[fieldName];
    }

    /**
     * @dev Gets all field names for an entity's component
     * @param entityId The entity
     * @param componentId The component
     * @return Array of field names that have been set
     */
    function getComponentFieldNames(EntityLib.EntityId entityId, ComponentId componentId)
        external
        view
        returns (string[] memory)
    {
        if (!hasComponent(entityId, componentId)) revert EntityDoesNotHaveComponent(entityId, componentId);
        return _entityComponentData[entityId][componentId].fieldNames;
    }

    /**
     * @dev Gets a component schema
     * @param componentId The component ID
     * @return The component schema
     */
    function getComponentSchema(ComponentId componentId) external view returns (ComponentSchema memory) {
        return _componentSchemas[componentId];
    }

    /**
     * @dev Gets all registered component IDs
     * @return Array of registered component IDs
     */
    function getRegisteredComponentIds() external view returns (ComponentId[] memory) {
        ComponentId[] memory result = new ComponentId[](_registeredComponentIds.length);
        for (uint256 i = 0; i < _registeredComponentIds.length; i++) {
            result[i] = _registeredComponentIds[i];
        }
        return result;
    }

    /**
     * @dev Checks if an entity has all specified components
     * @param entityId The entity to check
     * @param componentIds Array of component IDs to check for
     * @return True if the entity has all specified components
     */
    function hasAllComponents(EntityLib.EntityId entityId, ComponentId[] calldata componentIds)
        external
        view
        returns (bool)
    {
        for (uint256 i = 0; i < componentIds.length; i++) {
            if (!hasComponent(entityId, componentIds[i])) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Checks if an entity has any of the specified components
     * @param entityId The entity to check
     * @param componentIds Array of component IDs to check for
     * @return True if the entity has any of the specified components
     */
    function hasAnyComponent(EntityLib.EntityId entityId, ComponentId[] calldata componentIds)
        external
        view
        returns (bool)
    {
        for (uint256 i = 0; i < componentIds.length; i++) {
            if (hasComponent(entityId, componentIds[i])) {
                return true;
            }
        }
        return false;
    }

    // ============ INTERNAL HELPER FUNCTIONS ============

    /**
     * @dev Gets the datastore set key for an entity's components
     * @param entityId The entity ID
     * @return The set key for storing component IDs for this entity
     */
    function getEntityComponentsSetKey(EntityLib.EntityId entityId) public pure returns (DatastoreSetIdUint48) {
        return DatastoreSetIdUint48.wrap(keccak256(abi.encode(ENTITY_COMPONENTS_KEY_PARTIAL, entityId)));
    }

    /**
     * @dev Gets the datastore set key for a component's entities
     * @param componentId The component ID
     * @return The set key for storing entity IDs that have this component
     */
    function getComponentEntitiesSetKey(ComponentId componentId) public pure returns (DatastoreSetIdUint48) {
        return DatastoreSetIdUint48.wrap(keccak256(abi.encode(COMPONENT_ENTITIES_KEY_PARTIAL, componentId)));
    }

    // Events for compatibility with old interface
    event ComponentAddedToEntity(EntityLib.EntityId indexed entityId, ComponentId indexed componentId);
    event ComponentRemovedFromEntity(EntityLib.EntityId indexed entityId, ComponentId indexed componentId);
}
