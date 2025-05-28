// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity 0.8.30;

import {DatastoreSetUint256} from "./DatastoreSetUint256.sol";
import {DatastoreSetUint16} from "./DatastoreSetUint16.sol";
import {DatastoreSetUint32} from "./DatastoreSetUint32.sol";
import {DatastoreSetUint48} from "./DatastoreSetUint48.sol";
import {DatastoreSetBytes32} from "./DatastoreSetBytes32.sol";
import {DatastoreSetAddress} from "./DatastoreSetAddress.sol";
import {DatastoreSetComponent} from "./DatastoreSetComponent.sol";
import {DatastoreSetComponentField} from "./DatastoreSetComponentField.sol";
import {DatastoreSetEntity} from "./DatastoreSetEntity.sol";

/**
 * @title DatastoreSetWrapper
 * @dev Makes it easier for contracts to find the right registry. Does not contain any logic or hold any permissions.
 *      This contract is not a registry, it is a wrapper around the other registries.
 */
contract DatastoreSetWrapper {
    DatastoreSetUint256 public immutable DATASTORE_SET_UINT256;
    DatastoreSetBytes32 public immutable DATASTORE_SET_BYTES32;
    DatastoreSetAddress public immutable DATASTORE_SET_ADDRESS;

    DatastoreSetUint16 public immutable DATASTORE_SET_UINT16;
    DatastoreSetUint32 public immutable DATASTORE_SET_UINT32;
    DatastoreSetUint48 public immutable DATASTORE_SET_UINT48;

    DatastoreSetComponent public immutable DATASTORE_SET_COMPONENT;
    DatastoreSetComponentField public immutable DATASTORE_SET_COMPONENT_FIELD;
    DatastoreSetEntity public immutable DATASTORE_SET_ENTITY;

    constructor() {
        DATASTORE_SET_UINT256 = new DatastoreSetUint256();
        DATASTORE_SET_BYTES32 = new DatastoreSetBytes32();
        DATASTORE_SET_ADDRESS = new DatastoreSetAddress();

        DATASTORE_SET_UINT16 = new DatastoreSetUint16();
        DATASTORE_SET_UINT32 = new DatastoreSetUint32();
        DATASTORE_SET_UINT48 = new DatastoreSetUint48();

        DATASTORE_SET_COMPONENT = new DatastoreSetComponent();
        DATASTORE_SET_COMPONENT_FIELD = new DatastoreSetComponentField();
        DATASTORE_SET_ENTITY = new DatastoreSetEntity();
    }
}
