// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {EntityLib} from "../lib/EntityLib.sol";

type DatastoreSetIdEntity is bytes32;

/**
 * @title DatastoreSetEntity
 * @dev Allows a contract to manage multiple sets of EntityId values packed efficiently into bytes32 arrays
 * @notice Sets are meant to be owned by a permissioned contract, not a user, since the owner is msg.sender
 * @notice Packs 5 EntityId values (6 bytes each) into each bytes32 (30 bytes used, 2 bytes unused)
 */
contract DatastoreSetEntity {
    uint256 private constant ITEMS_PER_SLOT = 5; // 5 EntityIds per bytes32
    uint256 private constant UINT48_SIZE = 6; // 6 bytes per EntityId (which is uint48)

    struct PackedSet {
        bytes32[] data; // Packed data storage
        uint256 length; // Total number of EntityId items stored
        mapping(EntityLib.EntityId => uint256) indexOf; // item => index + 1
    }

    // Registry for EntityId sets - msg.sender => setId => set
    mapping(address owner => mapping(DatastoreSetIdEntity setId => PackedSet set)) private _entitySets;

    // Events
    event AddEntity(DatastoreSetIdEntity setId, EntityLib.EntityId data);
    event RemoveEntity(DatastoreSetIdEntity setId, EntityLib.EntityId data);

    // Errors
    error DatastoreSetEntity_IndexOutOfBounds();
    error DatastoreSetEntity_PositionOutOfBounds();

    /**
     * @dev Packs an EntityId value into a bytes32 slot at the specified position
     * @param slot The current bytes32 slot
     * @param position Position within the slot (0-4)
     * @param value The EntityId value to pack
     * @return The updated bytes32 slot
     */
    function _packEntityId(bytes32 slot, uint8 position, EntityLib.EntityId value) private pure returns (bytes32) {
        require(position < ITEMS_PER_SLOT, DatastoreSetEntity_PositionOutOfBounds());
        uint256 shift = position * 48; // 48 bits per EntityId
        uint256 mask = ~(uint256(0xFFFFFFFFFFFF) << shift);
        return bytes32((uint256(slot) & mask) | (uint256(EntityLib.EntityId.unwrap(value)) << shift));
    }

    /**
     * @dev Extracts an EntityId value from a bytes32 slot at the specified position
     * @param slot The bytes32 slot to extract from
     * @param position Position within the slot (0-4)
     * @return The extracted EntityId value
     */
    function _unpackEntityId(bytes32 slot, uint8 position) private pure returns (EntityLib.EntityId) {
        require(position < ITEMS_PER_SLOT, DatastoreSetEntity_PositionOutOfBounds());
        uint256 shift = position * 48; // 48 bits per EntityId
        uint48 value = uint48((uint256(slot) >> shift) & 0xFFFFFFFFFFFF);
        return EntityLib.EntityId.wrap(value);
    }

    /**
     * @dev Adds an EntityId item to the set if it doesn't already exist
     */
    function add(DatastoreSetIdEntity setId, EntityLib.EntityId item) external {
        PackedSet storage set = _entitySets[msg.sender][setId];

        if (set.indexOf[item] == 0) {
            // Item doesn't exist
            uint256 newIndex = set.length;
            uint256 slotIndex = newIndex / ITEMS_PER_SLOT;
            uint8 positionInSlot = uint8(newIndex % ITEMS_PER_SLOT);

            // Expand data array if needed
            if (slotIndex >= set.data.length) {
                set.data.push(bytes32(0));
            }

            // Pack the new item
            set.data[slotIndex] = _packEntityId(set.data[slotIndex], positionInSlot, item);
            set.length++;
            set.indexOf[item] = newIndex + 1; // Store index + 1

            emit AddEntity(setId, item);
        }
    }

    /**
     * @dev Adds multiple EntityId items to the set
     */
    function addBatch(DatastoreSetIdEntity setId, EntityLib.EntityId[] calldata items) external {
        PackedSet storage set = _entitySets[msg.sender][setId];

        for (uint256 i; i < items.length; i++) {
            EntityLib.EntityId item = items[i];

            if (!contains(msg.sender, setId, item)) {
                // Item doesn't exist
                uint256 newIndex = set.length;
                uint256 slotIndex = newIndex / ITEMS_PER_SLOT;
                uint8 positionInSlot = uint8(newIndex % ITEMS_PER_SLOT);

                // Expand data array if needed
                if (slotIndex >= set.data.length) {
                    set.data.push(bytes32(0));
                }

                // Pack the new item
                set.data[slotIndex] = _packEntityId(set.data[slotIndex], positionInSlot, item);
                set.length++;
                set.indexOf[item] = newIndex + 1; // Store index + 1

                emit AddEntity(setId, item);
            }
        }
    }

    /**
     * @dev Removes an EntityId item from the set if it exists
     * @notice Order is not preserved when removing items for gas efficiency
     */
    function remove(DatastoreSetIdEntity setId, EntityLib.EntityId item) external {
        PackedSet storage set = _entitySets[msg.sender][setId];
        uint256 indexPlusOne = set.indexOf[item];

        if (indexPlusOne > 0) {
            // Item exists
            uint256 indexToRemove = indexPlusOne - 1;
            uint256 lastIndex = set.length - 1;

            if (indexToRemove != lastIndex) {
                // Move the last item to the position of the item to remove
                EntityLib.EntityId lastItem = _getAtIndex(set, lastIndex);
                _setAtIndex(set, indexToRemove, lastItem);
                set.indexOf[lastItem] = indexToRemove + 1;
            }

            // Clear the last position and reduce length
            _clearAtIndex(set, lastIndex);
            set.length--;
            delete set.indexOf[item];

            // Remove empty trailing slots
            if (set.length > 0) {
                uint256 requiredSlots = (set.length + ITEMS_PER_SLOT - 1) / ITEMS_PER_SLOT;
                while (set.data.length > requiredSlots) {
                    set.data.pop();
                }
            } else {
                // Clear all data if set is empty
                delete set.data;
            }

            emit RemoveEntity(setId, item);
        }
    }

    /**
     * @dev Removes multiple EntityId items from the set
     * @notice Order is not preserved when removing items for gas efficiency
     */
    function removeBatch(DatastoreSetIdEntity setId, EntityLib.EntityId[] calldata items) external {
        PackedSet storage set = _entitySets[msg.sender][setId];

        for (uint256 i; i < items.length; i++) {
            EntityLib.EntityId item = items[i];
            uint256 indexPlusOne = set.indexOf[item];

            if (indexPlusOne > 0) {
                // Item exists
                uint256 indexToRemove = indexPlusOne - 1;
                uint256 lastIndex = set.length - 1;

                if (indexToRemove != lastIndex) {
                    // Move the last item to the position of the item to remove
                    EntityLib.EntityId lastItem = _getAtIndex(set, lastIndex);
                    _setAtIndex(set, indexToRemove, lastItem);
                    set.indexOf[lastItem] = indexToRemove + 1;
                }

                // Clear the last position and reduce length
                _clearAtIndex(set, lastIndex);
                set.length--;
                delete set.indexOf[item];

                emit RemoveEntity(setId, item);
            }
        }

        // Clean up empty trailing slots after batch removal
        if (set.length > 0) {
            uint256 requiredSlots = (set.length + ITEMS_PER_SLOT - 1) / ITEMS_PER_SLOT;
            while (set.data.length > requiredSlots) {
                set.data.pop();
            }
        } else {
            // Clear all data if set is empty
            delete set.data;
        }
    }

    /**
     * @dev Internal function to get item at specific index
     */
    function _getAtIndex(PackedSet storage set, uint256 index) private view returns (EntityLib.EntityId) {
        require(index < set.length, DatastoreSetEntity_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        return _unpackEntityId(set.data[slotIndex], positionInSlot);
    }

    /**
     * @dev Internal function to set item at specific index
     */
    function _setAtIndex(PackedSet storage set, uint256 index, EntityLib.EntityId value) private {
        require(index < set.length, DatastoreSetEntity_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        set.data[slotIndex] = _packEntityId(set.data[slotIndex], positionInSlot, value);
    }

    /**
     * @dev Internal function to clear item at specific index (set to 0)
     */
    function _clearAtIndex(PackedSet storage set, uint256 index) private {
        require(index < set.length, DatastoreSetEntity_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        set.data[slotIndex] = _packEntityId(set.data[slotIndex], positionInSlot, EntityLib.EntityId.wrap(0));
    }

    /**
     * @dev Checks if the set contains a specific EntityId item
     */
    function contains(address datastoreSetOwner, DatastoreSetIdEntity setId, EntityLib.EntityId item)
        public
        view
        returns (bool)
    {
        return _entitySets[datastoreSetOwner][setId].indexOf[item] > 0;
    }

    /**
     * @dev Returns the number of items in the set
     */
    function length(address datastoreSetOwner, DatastoreSetIdEntity setId) external view returns (uint256) {
        return _entitySets[datastoreSetOwner][setId].length;
    }

    /**
     * @dev Returns the item at the specified index
     */
    function at(address datastoreSetOwner, DatastoreSetIdEntity setId, uint256 index)
        external
        view
        returns (EntityLib.EntityId item)
    {
        PackedSet storage set = _entitySets[datastoreSetOwner][setId];
        return _getAtIndex(set, index);
    }

    /**
     * @dev Returns all items in the set
     */
    function getAll(address datastoreSetOwner, DatastoreSetIdEntity setId)
        external
        view
        returns (EntityLib.EntityId[] memory items)
    {
        PackedSet storage set = _entitySets[datastoreSetOwner][setId];
        items = new EntityLib.EntityId[](set.length);

        for (uint256 i; i < set.length; i++) {
            items[i] = _getAtIndex(set, i);
        }

        return items;
    }

    /**
     * @dev Returns a range of items from the set
     */
    function getFrom(address datastoreSetOwner, DatastoreSetIdEntity setId, uint256 index, uint256 count)
        public
        view
        returns (EntityLib.EntityId[] memory items)
    {
        PackedSet storage set = _entitySets[datastoreSetOwner][setId];
        uint256 totalLength = set.length;

        if (index >= totalLength) {
            return new EntityLib.EntityId[](0);
        }
        if (index + count > totalLength) {
            count = totalLength - index;
        }

        items = new EntityLib.EntityId[](count);
        for (uint256 i; i < count; i++) {
            items[i] = _getAtIndex(set, index + i);
        }

        return items;
    }

    /**
     * @dev Returns the last N items from the set
     */
    function getLast(address datastoreSetOwner, DatastoreSetIdEntity setId, uint256 count)
        external
        view
        returns (EntityLib.EntityId[] memory items)
    {
        PackedSet storage set = _entitySets[datastoreSetOwner][setId];
        uint256 totalLength = set.length;

        if (totalLength < count) {
            count = totalLength;
        }

        return getFrom(datastoreSetOwner, setId, totalLength - count, count);
    }
}
