// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
// Only for short strings (up to 31 bytes)
pragma solidity 0.8.30;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ShortStrings, ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";

type DatastoreShortStringId is bytes32;

contract DatastoreShortString {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using ShortStrings for ShortString;
    using ShortStrings for string;

    // Registry for bytes32 sets - msg.sender => setId => set
    mapping(address owner => mapping(DatastoreShortStringId setId => EnumerableSet.Bytes32Set set)) private
        _shortStringSets;

    // Events
    event AddShortString(DatastoreShortStringId setId, ShortString data);
    event RemoveShortString(DatastoreShortStringId setId, ShortString data);

    function add(DatastoreShortStringId setId, ShortString item) external {
        if (!_shortStringSets[msg.sender][setId].contains(ShortString.unwrap(item))) {
            _shortStringSets[msg.sender][setId].add(ShortString.unwrap(item));
            emit AddShortString(setId, item);
        }
    }

    function addBatch(DatastoreShortStringId setId, ShortString[] calldata items) external {
        for (uint256 i; i < items.length; i++) {
            if (!_shortStringSets[msg.sender][setId].contains(ShortString.unwrap(items[i]))) {
                _shortStringSets[msg.sender][setId].add(ShortString.unwrap(items[i]));
                emit AddShortString(setId, items[i]);
            }
        }
    }

    function remove(DatastoreShortStringId setId, ShortString item) external {
        if (_shortStringSets[msg.sender][setId].contains(ShortString.unwrap(item))) {
            _shortStringSets[msg.sender][setId].remove(ShortString.unwrap(item));
            emit RemoveShortString(setId, item);
        }
    }

    function removeBatch(DatastoreShortStringId setId, ShortString[] calldata items) external {
        for (uint256 i; i < items.length; i++) {
            if (_shortStringSets[msg.sender][setId].contains(ShortString.unwrap(items[i]))) {
                _shortStringSets[msg.sender][setId].remove(ShortString.unwrap(items[i]));
                emit RemoveShortString(setId, items[i]);
            }
        }
    }

    function contains(address datastoreSetOwner, DatastoreShortStringId setId, ShortString item)
        external
        view
        returns (bool)
    {
        return _shortStringSets[datastoreSetOwner][setId].contains(ShortString.unwrap(item));
    }

    function length(address datastoreSetOwner, DatastoreShortStringId setId) external view returns (uint256) {
        return _shortStringSets[datastoreSetOwner][setId].length();
    }

    function at(address datastoreSetOwner, DatastoreShortStringId setId, uint256 index)
        external
        view
        returns (ShortString item)
    {
        return ShortString.wrap(_shortStringSets[datastoreSetOwner][setId].at(index));
    }

    function getAll(address datastoreSetOwner, DatastoreShortStringId setId)
        external
        view
        returns (ShortString[] memory items)
    {
        bytes32[] memory itemsBytes32 = _shortStringSets[datastoreSetOwner][setId].values();
        items = new ShortString[](itemsBytes32.length);
        for (uint256 i; i < itemsBytes32.length; i++) {
            items[i] = ShortString.wrap(itemsBytes32[i]);
        }
        return items;
    }

    function getFrom(address datastoreSetOwner, DatastoreShortStringId setId, uint256 index, uint256 count)
        public
        view
        returns (ShortString[] memory items)
    {
        uint256 totalLength = _shortStringSets[datastoreSetOwner][setId].length();
        if (index >= totalLength) {
            return new ShortString[](0);
        }
        if (index + count > totalLength) {
            count = totalLength - index;
        }
        items = new ShortString[](count);
        for (uint256 i; i < count; i++) {
            items[i] = ShortString.wrap(_shortStringSets[datastoreSetOwner][setId].at(index + i));
        }
        return items;
    }

    function getLast(address datastoreSetOwner, DatastoreShortStringId setId, uint256 count)
        external
        view
        returns (ShortString[] memory items)
    {
        uint256 totalLength = _shortStringSets[datastoreSetOwner][setId].length();
        if (totalLength < count) {
            count = totalLength;
        }
        return getFrom(datastoreSetOwner, setId, totalLength - count, count);
    }
}
