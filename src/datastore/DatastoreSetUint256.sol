// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

type DatastoreSetIdUint256 is bytes32;

/**
 * @title DatastoreSetUint256
 * @dev Allows a contract to manage multiple sets of uint256
 * @notice Sets are meant to be owned by a permissioned contract, not a user, since the owner is msg.sender
 */
contract DatastoreSetUint256 {
    using EnumerableSet for EnumerableSet.UintSet;

    // Registry for uint256 sets - msg.sender => setId => set
    mapping(address owner => mapping(DatastoreSetIdUint256 setId => EnumerableSet.UintSet set)) private _uint256Sets;

    // Events
    event AddUint256(DatastoreSetIdUint256 setId, uint256 number);
    event RemoveUint256(DatastoreSetIdUint256 setId, uint256 number);

    function add(DatastoreSetIdUint256 setId, uint256 number) external {
        if (!_uint256Sets[msg.sender][setId].contains(number)) {
            _uint256Sets[msg.sender][setId].add(number);
            emit AddUint256(setId, number);
        }
    }

    function addBatch(DatastoreSetIdUint256 setId, uint256[] calldata numbers) external {
        for (uint256 i; i < numbers.length; i++) {
            uint256 number = numbers[i];
            if (!_uint256Sets[msg.sender][setId].contains(number)) {
                _uint256Sets[msg.sender][setId].add(number);
                emit AddUint256(setId, number);
            }
        }
    }

    function remove(DatastoreSetIdUint256 setId, uint256 number) external {
        if (_uint256Sets[msg.sender][setId].contains(number)) {
            _uint256Sets[msg.sender][setId].remove(number);
            emit RemoveUint256(setId, number);
        }
    }

    function removeBatch(DatastoreSetIdUint256 setId, uint256[] calldata numbers) external {
        for (uint256 i; i < numbers.length; i++) {
            uint256 number = numbers[i];
            if (_uint256Sets[msg.sender][setId].contains(number)) {
                _uint256Sets[msg.sender][setId].remove(number);
                emit RemoveUint256(setId, number);
            }
        }
    }

    function contains(address datastoreSetOwner, DatastoreSetIdUint256 setId, uint256 number)
        external
        view
        returns (bool)
    {
        return _uint256Sets[datastoreSetOwner][setId].contains(number);
    }

    function length(address datastoreSetOwner, DatastoreSetIdUint256 setId) external view returns (uint256) {
        return _uint256Sets[datastoreSetOwner][setId].length();
    }

    function at(address datastoreSetOwner, DatastoreSetIdUint256 setId, uint256 index)
        external
        view
        returns (uint256 number)
    {
        return _uint256Sets[datastoreSetOwner][setId].at(index);
    }

    function getAll(address datastoreSetOwner, DatastoreSetIdUint256 setId)
        external
        view
        returns (uint256[] memory numbers)
    {
        return _uint256Sets[datastoreSetOwner][setId].values();
    }

    function getFrom(address datastoreSetOwner, DatastoreSetIdUint256 setId, uint256 index, uint256 count)
        public
        view
        returns (uint256[] memory items)
    {
        uint256 totalLength = _uint256Sets[datastoreSetOwner][setId].length();
        if (index >= totalLength) {
            return new uint256[](0);
        }
        if (index + count > totalLength) {
            count = totalLength - index;
        }
        items = new uint256[](count);
        for (uint256 i; i < count; i++) {
            items[i] = _uint256Sets[datastoreSetOwner][setId].at(index + i);
        }
        return items;
    }

    function getLast(address datastoreSetOwner, DatastoreSetIdUint256 setId, uint256 count)
        external
        view
        returns (uint256[] memory items)
    {
        uint256 totalLength = _uint256Sets[datastoreSetOwner][setId].length();
        if (totalLength < count) {
            count = totalLength;
        }
        return getFrom(datastoreSetOwner, setId, totalLength - count, count);
    }
}
