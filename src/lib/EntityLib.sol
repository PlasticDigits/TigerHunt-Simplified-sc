// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {DatastoreSetIdUint16} from "../datastore/DatastoreSetUint16.sol";

library EntityLib {
    // Custom type definitions
    type EntityId is uint48; //2^48 is ~2.81e+14 entities

    function getEntityComponentSetKey(EntityId entityId) internal pure returns (DatastoreSetIdUint16) {
        return DatastoreSetIdUint16.wrap(keccak256(abi.encodePacked("ENTITY_COMPONENT_SET", entityId)));
    }
}
