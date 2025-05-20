// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

type DatastoreSetIdBytes32 is bytes32;

/**
 * @title DatastoreSetBytes32
 * @dev Allows a contract to manage multiple sets of bytes32
 * @notice Sets are meant to be owned by a permissioned contract, not a user, since the owner is msg.sender
 */
contract DatastoreSetBytes32 {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // Registry for bytes32 sets - msg.sender => setId => set
    mapping(address owner => mapping(DatastoreSetIdBytes32 setId => EnumerableSet.Bytes32Set set)) private _bytes32Sets;

    // Events
    event AddBytes32(DatastoreSetIdBytes32 setId, bytes32 data);
    event RemoveBytes32(DatastoreSetIdBytes32 setId, bytes32 data);

    function add(DatastoreSetIdBytes32 setId, bytes32 item) external {
        if (!_bytes32Sets[msg.sender][setId].contains(item)) {
            _bytes32Sets[msg.sender][setId].add(item);
            emit AddBytes32(setId, item);
        }
    }

    function addBatch(DatastoreSetIdBytes32 setId, bytes32[] calldata items) external {
        for (uint256 i; i < items.length; i++) {
            bytes32 item = items[i];
            if (!_bytes32Sets[msg.sender][setId].contains(item)) {
                _bytes32Sets[msg.sender][setId].add(item);
                emit AddBytes32(setId, item);
            }
        }
    }

    function remove(DatastoreSetIdBytes32 setId, bytes32 item) external {
        if (_bytes32Sets[msg.sender][setId].contains(item)) {
            _bytes32Sets[msg.sender][setId].remove(item);
            emit RemoveBytes32(setId, item);
        }
    }

    function removeBatch(DatastoreSetIdBytes32 setId, bytes32[] calldata items) external {
        for (uint256 i; i < items.length; i++) {
            bytes32 item = items[i];
            if (_bytes32Sets[msg.sender][setId].contains(item)) {
                _bytes32Sets[msg.sender][setId].remove(item);
                emit RemoveBytes32(setId, item);
            }
        }
    }

    function contains(address datastoreSetOwner, DatastoreSetIdBytes32 setId, bytes32 item)
        external
        view
        returns (bool)
    {
        return _bytes32Sets[datastoreSetOwner][setId].contains(item);
    }

    function length(address datastoreSetOwner, DatastoreSetIdBytes32 setId) external view returns (uint256) {
        return _bytes32Sets[datastoreSetOwner][setId].length();
    }

    function at(address datastoreSetOwner, DatastoreSetIdBytes32 setId, uint256 index)
        external
        view
        returns (bytes32 item)
    {
        return _bytes32Sets[datastoreSetOwner][setId].at(index);
    }

    function getAll(address datastoreSetOwner, DatastoreSetIdBytes32 setId)
        external
        view
        returns (bytes32[] memory items)
    {
        return _bytes32Sets[datastoreSetOwner][setId].values();
    }

    function getFrom(address datastoreSetOwner, DatastoreSetIdBytes32 setId, uint256 index, uint256 count)
        public
        view
        returns (bytes32[] memory items)
    {
        uint256 totalLength = _bytes32Sets[datastoreSetOwner][setId].length();
        if (index >= totalLength) {
            return new bytes32[](0);
        }
        if (index + count > totalLength) {
            count = totalLength - index;
        }
        items = new bytes32[](count);
        for (uint256 i; i < count; i++) {
            items[i] = _bytes32Sets[datastoreSetOwner][setId].at(index + i);
        }
        return items;
    }

    function getLast(address datastoreSetOwner, DatastoreSetIdBytes32 setId, uint256 count)
        external
        view
        returns (bytes32[] memory items)
    {
        uint256 totalLength = _bytes32Sets[datastoreSetOwner][setId].length();
        if (totalLength < count) {
            count = totalLength;
        }
        return getFrom(datastoreSetOwner, setId, totalLength - count, count);
    }
}
