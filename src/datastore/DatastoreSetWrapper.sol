// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity 0.8.30;

import {DatastoreSetAddress} from "./DatastoreSetAddress.sol";
import {DatastoreSetBytes32} from "./DatastoreSetBytes32.sol";
import {DatastoreSetUint256} from "./DatastoreSetUint256.sol";
import {DatastoreSetUint16} from "./DatastoreSetUint16.sol";
import {DatastoreSetUint32} from "./DatastoreSetUint32.sol";
import {DatastoreSetUint48} from "./DatastoreSetUint48.sol";

/**
 * @title DatastoreSetWrapper
 * @dev Makes it easier for contracts to find the right registry. Does not contain any logic or hold any permissions.
 *      This contract is not a registry, it is a wrapper around the other registries.
 */
contract DatastoreSetWrapper {
    DatastoreSetAddress public immutable DATASTORE_SET_ADDRESS;
    DatastoreSetBytes32 public immutable DATASTORE_SET_BYTES32;
    DatastoreSetUint256 public immutable DATASTORE_SET_UINT256;
    DatastoreSetUint16 public immutable DATASTORE_SET_UINT16;
    DatastoreSetUint32 public immutable DATASTORE_SET_UINT32;
    DatastoreSetUint48 public immutable DATASTORE_SET_UINT48;

    constructor() {
        DATASTORE_SET_ADDRESS = new DatastoreSetAddress();
        DATASTORE_SET_BYTES32 = new DatastoreSetBytes32();
        DATASTORE_SET_UINT256 = new DatastoreSetUint256();
        DATASTORE_SET_UINT16 = new DatastoreSetUint16();
        DATASTORE_SET_UINT32 = new DatastoreSetUint32();
        DATASTORE_SET_UINT48 = new DatastoreSetUint48();
    }
}
