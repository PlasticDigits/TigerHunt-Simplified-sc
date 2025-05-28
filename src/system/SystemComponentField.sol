// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdComponentField} from "../datastore/DatastoreSetComponentField.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ComponentLib} from "../lib/ComponentLib.sol";

/**
 * @title SystemComponentField
 * @dev Manages the creation, updating, and removal of component fields in the ECS system
 * @notice Uses AccessManaged to restrict state-changing operations to authorized users
 * @notice Uses DatastoreSetComponentField to efficiently store component field IDs
 */
contract SystemComponentField is AccessManaged {
    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;

    // Component field data storage
    mapping(ComponentLib.ComponentFieldId id => ComponentLib.ComponentField field) private _componentFields;

    // Nonce for generating new field IDs
    uint16 private _nonce;

    // Errors
    error SystemComponentField_FieldNotFound();
    error SystemComponentField_FieldAlreadyExists();

    constructor(DatastoreSetWrapper datastoreSetWrapper, address accessAuthority) AccessManaged(accessAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
        _nonce = 0;
    }

    /**
     * @dev Creates a new component field
     * @param field The component field definition to create
     */
    function create(ComponentLib.ComponentField calldata field) external restricted {
        ComponentLib.ComponentField memory newField = field;

        // Generate ID if not provided
        if (ComponentLib.ComponentFieldId.unwrap(field.id) == 0) {
            newField.id = _generateFieldId();
        }

        if (
            DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(
                address(this), getGlobalComponentFieldRegistrySetId(), newField.id
            )
        ) {
            revert SystemComponentField_FieldAlreadyExists();
        }

        _componentFields[newField.id] = newField;

        // Add field ID to the global component field registry
        DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().add(getGlobalComponentFieldRegistrySetId(), newField.id);
    }

    /**
     * @dev Updates an existing component field
     * @param field The updated component field definition
     */
    function update(ComponentLib.ComponentField calldata field) external restricted {
        if (
            !DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(
                address(this), getGlobalComponentFieldRegistrySetId(), field.id
            )
        ) {
            revert SystemComponentField_FieldNotFound();
        }

        _componentFields[field.id] = field;
    }

    /**
     * @dev Removes a component field from the system
     * @param fieldId The component field identifier to remove
     */
    function remove(ComponentLib.ComponentFieldId fieldId) external restricted {
        if (
            !DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(
                address(this), getGlobalComponentFieldRegistrySetId(), fieldId
            )
        ) {
            revert SystemComponentField_FieldNotFound();
        }

        // Remove field ID from the global component field registry
        DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().remove(getGlobalComponentFieldRegistrySetId(), fieldId);

        // Clean up field data
        delete _componentFields[fieldId];
    }

    /**
     * @dev Batch creates multiple component fields
     * @param fields Array of component field definitions to create
     */
    function createBatch(ComponentLib.ComponentField[] calldata fields) external restricted {
        ComponentLib.ComponentFieldId[] memory fieldIds = new ComponentLib.ComponentFieldId[](fields.length);
        ComponentLib.ComponentField[] memory newFields = new ComponentLib.ComponentField[](fields.length);

        for (uint256 i = 0; i < fields.length; i++) {
            ComponentLib.ComponentField memory newField = fields[i];

            // Generate ID if not provided
            if (ComponentLib.ComponentFieldId.unwrap(fields[i].id) == 0) {
                newField.id = _generateFieldId();
            }

            if (
                DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(
                    address(this), getGlobalComponentFieldRegistrySetId(), newField.id
                )
            ) {
                revert SystemComponentField_FieldAlreadyExists();
            }

            _componentFields[newField.id] = newField;
            fieldIds[i] = newField.id;
            newFields[i] = newField;
        }

        // Add all field IDs to the global component field registry in batch
        DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().addBatch(getGlobalComponentFieldRegistrySetId(), fieldIds);
    }

    /**
     * @dev Batch removes multiple component fields
     * @param fieldIds Array of component field identifiers to remove
     */
    function removeBatch(ComponentLib.ComponentFieldId[] calldata fieldIds) external restricted {
        for (uint256 i = 0; i < fieldIds.length; i++) {
            ComponentLib.ComponentFieldId fieldId = fieldIds[i];

            if (
                !DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(
                    address(this), getGlobalComponentFieldRegistrySetId(), fieldId
                )
            ) {
                revert SystemComponentField_FieldNotFound();
            }

            // Clean up field data
            delete _componentFields[fieldId];
        }

        // Remove all field IDs from the global component field registry in batch
        DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().removeBatch(
            getGlobalComponentFieldRegistrySetId(), fieldIds
        );
    }

    /**
     * @dev Generates a new unique field ID using nonce
     * @return fieldId The generated field ID
     */
    function _generateFieldId() private returns (ComponentLib.ComponentFieldId fieldId) {
        do {
            fieldId = ComponentLib.ComponentFieldId.wrap(_nonce);
            _nonce++;
        } while (
            DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(
                address(this), getGlobalComponentFieldRegistrySetId(), fieldId
            )
        );

        return fieldId;
    }

    // View functions

    /**
     * @dev Returns the global component field registry set identifier
     */
    function getGlobalComponentFieldRegistrySetId() public pure returns (DatastoreSetIdComponentField) {
        return DatastoreSetIdComponentField.wrap(keccak256("GLOBAL_COMPONENT_FIELD_REGISTRY"));
    }

    /**
     * @dev Checks if a component field exists
     * @param fieldId The component field identifier to check
     * @return True if the field exists
     */
    function exists(ComponentLib.ComponentFieldId fieldId) external view returns (bool) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(
            address(this), getGlobalComponentFieldRegistrySetId(), fieldId
        );
    }

    /**
     * @dev Returns component field information
     * @param fieldId The component field identifier
     * @return field The component field definition
     */
    function get(ComponentLib.ComponentFieldId fieldId)
        external
        view
        returns (ComponentLib.ComponentField memory field)
    {
        if (
            !DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().contains(
                address(this), getGlobalComponentFieldRegistrySetId(), fieldId
            )
        ) {
            revert SystemComponentField_FieldNotFound();
        }

        return _componentFields[fieldId];
    }

    /**
     * @dev Returns component field at the specified index
     * @param index The index to retrieve
     * @return field The component field definition
     */
    function at(uint256 index) external view returns (ComponentLib.ComponentField memory field) {
        ComponentLib.ComponentFieldId fieldId = DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().at(
            address(this), getGlobalComponentFieldRegistrySetId(), index
        );
        return _componentFields[fieldId];
    }

    /**
     * @dev Returns all registered component fields
     * @return fields Array of all component field definitions
     */
    function getAll() external view returns (ComponentLib.ComponentField[] memory fields) {
        ComponentLib.ComponentFieldId[] memory fieldIds = DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().getAll(
            address(this), getGlobalComponentFieldRegistrySetId()
        );
        fields = new ComponentLib.ComponentField[](fieldIds.length);

        for (uint256 i = 0; i < fieldIds.length; i++) {
            fields[i] = _componentFields[fieldIds[i]];
        }

        return fields;
    }

    /**
     * @dev Returns the total number of registered component fields
     * @return count The number of component fields
     */
    function getCount() external view returns (uint256 count) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_COMPONENT_FIELD().length(
            address(this), getGlobalComponentFieldRegistrySetId()
        );
    }

    /**
     * @dev Returns the current nonce value
     * @return nonce The current nonce
     */
    function getNonce() external view returns (uint16 nonce) {
        return _nonce;
    }
}
