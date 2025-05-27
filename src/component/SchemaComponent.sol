// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {EntityLib} from "../lib/EntityLib.sol";

type ComponentId is uint16;

/**
 * @title SchemaComponent
 * @dev Defines component schema, data structures, and types for the ECS system
 * @notice Components are pure data - no logic, only state
 */

/**
 * @dev Enum defining common data types for component values
 * Used to specify what kind of data a component field contains
 */
enum ComponentDataType {
    // solidity types
    NONE, // Empty/unused field
    BOOL, // Boolean value
    UINT256, // Maximum integer / wei amounts
    INT256, // Maximum signed integer
    ADDRESS, // Ethereum address
    BYTES32, // Hash/identifier
    STRING, // Text data
    BYTES, // Binary blob
    // custom types
    POINT_3D, // 3D point
    DAY_IN_GAME, // Day in game (uint16)
    // reference types
    ENTITY_ID, // Reference to another entity
    COMPONENT_ID, // Reference to a component
    // reference types: datastores
    DATASTORE_SET_ID_UINT16, // Datastore Set of uint16 values (component set)
    DATASTORE_SET_ID_UINT32, // Datastore Set of uint32 values
    DATASTORE_SET_ID_UINT48, // Datastore Set of uint48 values (entity set)
    DATASTORE_SET_ID_UINT256, // Datastore Set of uint256 values
    DATASTORE_SET_ID_BYTES32, // Datastore Set of bytes32 values
    DATASTORE_SET_ID_ADDRESS, // Datastore Set of addresses
    DATASTORE_SET_ID_ENTITY_ID, // Datastore Set of entity IDs
    DATASTORE_SET_ID_COMPONENT_ID, // Datastore Set of component IDs
    DATASTORE_LOGBOOK_ID, // Datastore of a logbook
}

/**
 * @dev Component field definition
 * Describes a single field within a component
 */
struct ComponentField {
    string name; // Human-readable field name
    ComponentDataType dataType; // Type of data stored
    bool required; // Whether this field must have a value
    string description; // Description of what this field represents
}

/**
 * @dev Component schema definition
 * Describes the structure of a component type
 */
struct ComponentSchema {
    ComponentId id; // Unique component identifier
    string name; // Human-readable component name
    string description; // What this component represents
    ComponentField[] fields; // Field definitions
    bool isActive; // Whether this component type is active
}

/**
 * @dev Union type for component field values
 * Allows storing different data types in a single struct
 */
struct ComponentValue {
    ComponentDataType dataType;
    // Single value storage
    bool boolValue;
    uint256 uintValue; // Used for all uint types
    int256 intValue; // Used for all int types
    address addressValue;
    bytes32 bytes32Value;
    string stringValue;
    // Array storage
    uint16[] uint16Array;
    uint48[] uint48Array; // For entity ID arrays
    address[] addressArray;
    bytes32[] bytes32Array;
}

/**
 * @dev Complete component data for an entity
 * Maps field names to their values
 */
struct ComponentData {
    ComponentId componentId;
    mapping(string => ComponentValue) fieldValues;
    string[] fieldNames; // Track which fields have been set
}

/**
 * @dev Events for component data changes
 */
interface IComponentDataEvents {
    event ComponentDataSet(
        EntityLib.EntityId indexed entityId,
        ComponentId indexed componentId,
        string fieldName,
        ComponentDataType dataType
    );

    event ComponentDataCleared(EntityLib.EntityId indexed entityId, ComponentId indexed componentId, string fieldName);

    event ComponentSchemaRegistered(ComponentId indexed componentId, string name);

    event ComponentSchemaUpdated(ComponentId indexed componentId, string name);
}
