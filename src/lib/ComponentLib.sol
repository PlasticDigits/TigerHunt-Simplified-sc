// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {DatastoreSetIdUint16} from "../datastore/DatastoreSetUint16.sol";
import {DatastoreSetIdUint48} from "../datastore/DatastoreSetUint48.sol";

library ComponentLib {
    type ComponentId is uint16; //2^16 is 65,536 components

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
        DATASTORE_SET_ID_ENTITY, // Datastore Set of entity IDs
        DATASTORE_SET_ID_COMPONENT, // Datastore Set of component IDs
        DATASTORE_LOGBOOK_ID // Datastore of a logbook

    }

    type ComponentFieldId is uint16;

    /**
     * @dev Component field definition
     * Describes a single field within a component
     */
    struct ComponentField {
        ComponentFieldId id; // Unique field identifier
        ComponentDataType dataType; // Type of data stored
        string name; // Human-readable field name
        string description; // Description of what this field represents
    }

    function getComponentFieldSetKey(ComponentId componentId) internal pure returns (DatastoreSetIdUint16) {
        return DatastoreSetIdUint16.wrap(keccak256(abi.encodePacked("COMPONENT_FIELD_SET", componentId)));
    }

    function getComponentEntitySetKey(ComponentId componentId) internal pure returns (DatastoreSetIdUint48) {
        return DatastoreSetIdUint48.wrap(keccak256(abi.encodePacked("COMPONENT_ENTITY_SET", componentId)));
    }
}
