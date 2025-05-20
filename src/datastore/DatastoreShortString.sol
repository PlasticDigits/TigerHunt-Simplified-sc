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

    function add(DatastoreShortStringId setId, string calldata item) external {
        ShortString s = item.toShortString();
        if (!_shortStringSets[msg.sender][setId].contains(ShortString.unwrap(s))) {
            _shortStringSets[msg.sender][setId].add(ShortString.unwrap(s));
            emit AddShortString(setId, s);
        }
    }

    function addBatch(DatastoreShortStringId setId, string[] calldata items) external {
        for (uint256 i; i < items.length; i++) {
            ShortString s = items[i].toShortString();
            if (!_shortStringSets[msg.sender][setId].contains(ShortString.unwrap(s))) {
                _shortStringSets[msg.sender][setId].add(ShortString.unwrap(s));
                emit AddShortString(setId, s);
            }
        }
    }

    function remove(DatastoreShortStringId setId, string calldata item) external {
        ShortString s = item.toShortString();
        if (_shortStringSets[msg.sender][setId].contains(ShortString.unwrap(s))) {
            _shortStringSets[msg.sender][setId].remove(ShortString.unwrap(s));
            emit RemoveShortString(setId, s);
        }
    }

    function removeBatch(DatastoreShortStringId setId, string[] calldata items) external {
        for (uint256 i; i < items.length; i++) {
            ShortString s = items[i].toShortString();
            if (_shortStringSets[msg.sender][setId].contains(ShortString.unwrap(s))) {
                _shortStringSets[msg.sender][setId].remove(ShortString.unwrap(s));
                emit RemoveShortString(setId, s);
            }
        }
    }

    function contains(address datastoreSetOwner, DatastoreShortStringId setId, string calldata item)
        external
        view
        returns (bool)
    {
        return _shortStringSets[datastoreSetOwner][setId].contains(ShortString.unwrap(item.toShortString()));
    }

    function length(address datastoreSetOwner, DatastoreShortStringId setId) external view returns (uint256) {
        return _shortStringSets[datastoreSetOwner][setId].length();
    }

    function at(address datastoreSetOwner, DatastoreShortStringId setId, uint256 index)
        external
        view
        returns (string memory item)
    {
        return ShortString.wrap(_shortStringSets[datastoreSetOwner][setId].at(index)).toString();
    }

    function getAll(address datastoreSetOwner, DatastoreShortStringId setId)
        external
        view
        returns (string[] memory items)
    {
        bytes32[] memory itemsBytes32 = _shortStringSets[datastoreSetOwner][setId].values();
        items = new string[](itemsBytes32.length);
        for (uint256 i; i < itemsBytes32.length; i++) {
            items[i] = ShortString.wrap(itemsBytes32[i]).toString();
        }
        return items;
    }

    function getFrom(address datastoreSetOwner, DatastoreShortStringId setId, uint256 index, uint256 count)
        public
        view
        returns (string[] memory items)
    {
        uint256 totalLength = _shortStringSets[datastoreSetOwner][setId].length();
        if (index >= totalLength) {
            return new string[](0);
        }
        if (index + count > totalLength) {
            count = totalLength - index;
        }
        items = new string[](count);
        for (uint256 i; i < count; i++) {
            items[i] = ShortString.wrap(_shortStringSets[datastoreSetOwner][setId].at(index + i)).toString();
        }
        return items;
    }

    function getLast(address datastoreSetOwner, DatastoreShortStringId setId, uint256 count)
        external
        view
        returns (string[] memory items)
    {
        uint256 totalLength = _shortStringSets[datastoreSetOwner][setId].length();
        if (totalLength < count) {
            count = totalLength;
        }
        return getFrom(datastoreSetOwner, setId, totalLength - count, count);
    }
}
