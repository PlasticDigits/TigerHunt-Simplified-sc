// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

type DatastoreSetIdUint48 is bytes32;

/**
 * @title DatastoreSetUint48
 * @dev Allows a contract to manage multiple sets of uint48 values packed efficiently into bytes32 arrays
 * @notice Sets are meant to be owned by a permissioned contract, not a user, since the owner is msg.sender
 * @notice Packs 5 uint48 values (6 bytes each) into each bytes32 (30 bytes used, 2 bytes unused)
 */
contract DatastoreSetUint48 {
    uint256 private constant ITEMS_PER_SLOT = 5; // 5 uint48s per bytes32
    uint256 private constant UINT48_SIZE = 6; // 6 bytes per uint48

    struct PackedSet {
        bytes32[] data; // Packed data storage
        uint256 length; // Total number of uint48 items stored
        mapping(uint48 => uint256) indexOf; // item => index + 1
    }

    // Registry for uint48 sets - msg.sender => setId => set
    mapping(address owner => mapping(DatastoreSetIdUint48 setId => PackedSet set)) private _uint48Sets;

    // Events
    event AddUint48(DatastoreSetIdUint48 setId, uint48 data);
    event RemoveUint48(DatastoreSetIdUint48 setId, uint48 data);

    // Errors
    error DatastoreSetUint48_IndexOutOfBounds();
    error DatastoreSetUint48_PositionOutOfBounds();

    /**
     * @dev Packs a uint48 value into a bytes32 slot at the specified position
     * @param slot The current bytes32 slot
     * @param position Position within the slot (0-4)
     * @param value The uint48 value to pack
     * @return The updated bytes32 slot
     */
    function _packUint48(bytes32 slot, uint8 position, uint48 value) private pure returns (bytes32) {
        require(position < ITEMS_PER_SLOT, DatastoreSetUint48_PositionOutOfBounds());
        uint256 shift = position * 48; // 48 bits per uint48
        uint256 mask = ~(uint256(0xFFFFFFFFFFFF) << shift);
        return bytes32((uint256(slot) & mask) | (uint256(value) << shift));
    }

    /**
     * @dev Extracts a uint48 value from a bytes32 slot at the specified position
     * @param slot The bytes32 slot to extract from
     * @param position Position within the slot (0-4)
     * @return The extracted uint48 value
     */
    function _unpackUint48(bytes32 slot, uint8 position) private pure returns (uint48) {
        require(position < ITEMS_PER_SLOT, DatastoreSetUint48_PositionOutOfBounds());
        uint256 shift = position * 48; // 48 bits per uint48
        return uint48((uint256(slot) >> shift) & 0xFFFFFFFFFFFF);
    }

    /**
     * @dev Adds a uint48 item to the set if it doesn't already exist
     */
    function add(DatastoreSetIdUint48 setId, uint48 item) external {
        PackedSet storage set = _uint48Sets[msg.sender][setId];

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
            set.data[slotIndex] = _packUint48(set.data[slotIndex], positionInSlot, item);
            set.length++;
            set.indexOf[item] = newIndex + 1; // Store index + 1

            emit AddUint48(setId, item);
        }
    }

    /**
     * @dev Adds multiple uint48 items to the set
     */
    function addBatch(DatastoreSetIdUint48 setId, uint48[] calldata items) external {
        PackedSet storage set = _uint48Sets[msg.sender][setId];

        for (uint256 i; i < items.length; i++) {
            uint48 item = items[i];

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
                set.data[slotIndex] = _packUint48(set.data[slotIndex], positionInSlot, item);
                set.length++;
                set.indexOf[item] = newIndex + 1; // Store index + 1

                emit AddUint48(setId, item);
            }
        }
    }

    /**
     * @dev Removes a uint48 item from the set if it exists
     * @notice Order is not preserved when removing items for gas efficiency
     */
    function remove(DatastoreSetIdUint48 setId, uint48 item) external {
        PackedSet storage set = _uint48Sets[msg.sender][setId];
        uint256 indexPlusOne = set.indexOf[item];

        if (indexPlusOne > 0) {
            // Item exists
            uint256 indexToRemove = indexPlusOne - 1;
            uint256 lastIndex = set.length - 1;

            if (indexToRemove != lastIndex) {
                // Move the last item to the position of the item to remove
                uint48 lastItem = _getAtIndex(set, lastIndex);
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

            emit RemoveUint48(setId, item);
        }
    }

    /**
     * @dev Removes multiple uint48 items from the set
     * @notice Order is not preserved when removing items for gas efficiency
     */
    function removeBatch(DatastoreSetIdUint48 setId, uint48[] calldata items) external {
        PackedSet storage set = _uint48Sets[msg.sender][setId];

        for (uint256 i; i < items.length; i++) {
            uint48 item = items[i];
            uint256 indexPlusOne = set.indexOf[item];

            if (indexPlusOne > 0) {
                // Item exists
                uint256 indexToRemove = indexPlusOne - 1;
                uint256 lastIndex = set.length - 1;

                if (indexToRemove != lastIndex) {
                    // Move the last item to the position of the item to remove
                    uint48 lastItem = _getAtIndex(set, lastIndex);
                    _setAtIndex(set, indexToRemove, lastItem);
                    set.indexOf[lastItem] = indexToRemove + 1;
                }

                // Clear the last position and reduce length
                _clearAtIndex(set, lastIndex);
                set.length--;
                delete set.indexOf[item];

                emit RemoveUint48(setId, item);
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
    function _getAtIndex(PackedSet storage set, uint256 index) private view returns (uint48) {
        require(index < set.length, DatastoreSetUint48_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        return _unpackUint48(set.data[slotIndex], positionInSlot);
    }

    /**
     * @dev Internal function to set item at specific index
     */
    function _setAtIndex(PackedSet storage set, uint256 index, uint48 value) private {
        require(index < set.length, DatastoreSetUint48_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        set.data[slotIndex] = _packUint48(set.data[slotIndex], positionInSlot, value);
    }

    /**
     * @dev Internal function to clear item at specific index (set to 0)
     */
    function _clearAtIndex(PackedSet storage set, uint256 index) private {
        require(index < set.length, DatastoreSetUint48_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        set.data[slotIndex] = _packUint48(set.data[slotIndex], positionInSlot, 0);
    }

    /**
     * @dev Checks if the set contains a specific uint48 item
     */
    function contains(address datastoreSetOwner, DatastoreSetIdUint48 setId, uint48 item) public view returns (bool) {
        return _uint48Sets[datastoreSetOwner][setId].indexOf[item] > 0;
    }

    /**
     * @dev Returns the number of items in the set
     */
    function length(address datastoreSetOwner, DatastoreSetIdUint48 setId) external view returns (uint256) {
        return _uint48Sets[datastoreSetOwner][setId].length;
    }

    /**
     * @dev Returns the item at the specified index
     */
    function at(address datastoreSetOwner, DatastoreSetIdUint48 setId, uint256 index)
        external
        view
        returns (uint48 item)
    {
        PackedSet storage set = _uint48Sets[datastoreSetOwner][setId];
        return _getAtIndex(set, index);
    }

    /**
     * @dev Returns all items in the set
     */
    function getAll(address datastoreSetOwner, DatastoreSetIdUint48 setId)
        external
        view
        returns (uint48[] memory items)
    {
        PackedSet storage set = _uint48Sets[datastoreSetOwner][setId];
        items = new uint48[](set.length);

        for (uint256 i; i < set.length; i++) {
            items[i] = _getAtIndex(set, i);
        }

        return items;
    }

    /**
     * @dev Returns a range of items from the set
     */
    function getFrom(address datastoreSetOwner, DatastoreSetIdUint48 setId, uint256 index, uint256 count)
        public
        view
        returns (uint48[] memory items)
    {
        PackedSet storage set = _uint48Sets[datastoreSetOwner][setId];
        uint256 totalLength = set.length;

        if (index >= totalLength) {
            return new uint48[](0);
        }
        if (index + count > totalLength) {
            count = totalLength - index;
        }

        items = new uint48[](count);
        for (uint256 i; i < count; i++) {
            items[i] = _getAtIndex(set, index + i);
        }

        return items;
    }

    /**
     * @dev Returns the last N items from the set
     */
    function getLast(address datastoreSetOwner, DatastoreSetIdUint48 setId, uint256 count)
        external
        view
        returns (uint48[] memory items)
    {
        PackedSet storage set = _uint48Sets[datastoreSetOwner][setId];
        uint256 totalLength = set.length;

        if (totalLength < count) {
            count = totalLength;
        }

        return getFrom(datastoreSetOwner, setId, totalLength - count, count);
    }
}
