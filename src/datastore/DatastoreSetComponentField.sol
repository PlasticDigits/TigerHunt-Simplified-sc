// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {ComponentLib} from "../lib/ComponentLib.sol";

type DatastoreSetIdComponentField is bytes32;

/**
 * @title DatastoreSetComponentField
 * @dev Allows a contract to manage multiple sets of ComponentFieldId values packed efficiently into bytes32 arrays
 * @notice Sets are meant to be owned by a permissioned contract, not a user, since the owner is msg.sender
 * @notice Packs 16 ComponentFieldId values (2 bytes each) into each bytes32 (32 bytes total)
 */
contract DatastoreSetComponentField {
    uint256 private constant ITEMS_PER_SLOT = 16; // 16 ComponentFieldIds per bytes32
    uint256 private constant COMPONENT_FIELD_SIZE = 2; // 2 bytes per ComponentFieldId

    struct PackedSet {
        bytes32[] data; // Packed data storage
        uint256 length; // Total number of ComponentFieldId items stored
        mapping(ComponentLib.ComponentFieldId => uint256) indexOf; // item => index + 1
    }

    // Registry for ComponentFieldId sets - msg.sender => setId => set
    mapping(address owner => mapping(DatastoreSetIdComponentField setId => PackedSet set)) private _componentFieldSets;

    // Events
    event AddComponentField(DatastoreSetIdComponentField setId, ComponentLib.ComponentFieldId data);
    event RemoveComponentField(DatastoreSetIdComponentField setId, ComponentLib.ComponentFieldId data);

    // Errors
    error DatastoreSetComponentField_IndexOutOfBounds();
    error DatastoreSetComponentField_PositionOutOfBounds();

    /**
     * @dev Packs a ComponentFieldId value into a bytes32 slot at the specified position
     * @param slot The current bytes32 slot
     * @param position Position within the slot (0-15)
     * @param value The ComponentFieldId value to pack
     * @return The updated bytes32 slot
     */
    function _packComponentField(bytes32 slot, uint8 position, ComponentLib.ComponentFieldId value)
        private
        pure
        returns (bytes32)
    {
        require(position < ITEMS_PER_SLOT, DatastoreSetComponentField_PositionOutOfBounds());
        uint256 shift = position * 16; // 16 bits per ComponentFieldId
        uint256 mask = ~(uint256(0xFFFF) << shift);
        return bytes32((uint256(slot) & mask) | (uint256(ComponentLib.ComponentFieldId.unwrap(value)) << shift));
    }

    /**
     * @dev Extracts a ComponentFieldId value from a bytes32 slot at the specified position
     * @param slot The bytes32 slot to extract from
     * @param position Position within the slot (0-15)
     * @return The extracted ComponentFieldId value
     */
    function _unpackComponentField(bytes32 slot, uint8 position) private pure returns (ComponentLib.ComponentFieldId) {
        require(position < ITEMS_PER_SLOT, DatastoreSetComponentField_PositionOutOfBounds());
        uint256 shift = position * 16; // 16 bits per ComponentFieldId
        return ComponentLib.ComponentFieldId.wrap(uint16((uint256(slot) >> shift) & 0xFFFF));
    }

    /**
     * @dev Adds a ComponentFieldId item to the set if it doesn't already exist
     */
    function add(DatastoreSetIdComponentField setId, ComponentLib.ComponentFieldId item) external {
        PackedSet storage set = _componentFieldSets[msg.sender][setId];

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
            set.data[slotIndex] = _packComponentField(set.data[slotIndex], positionInSlot, item);
            set.length++;
            set.indexOf[item] = newIndex + 1; // Store index + 1

            emit AddComponentField(setId, item);
        }
    }

    /**
     * @dev Adds multiple ComponentFieldId items to the set
     */
    function addBatch(DatastoreSetIdComponentField setId, ComponentLib.ComponentFieldId[] calldata items) external {
        PackedSet storage set = _componentFieldSets[msg.sender][setId];

        for (uint256 i; i < items.length; i++) {
            ComponentLib.ComponentFieldId item = items[i];

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
                set.data[slotIndex] = _packComponentField(set.data[slotIndex], positionInSlot, item);
                set.length++;
                set.indexOf[item] = newIndex + 1; // Store index + 1

                emit AddComponentField(setId, item);
            }
        }
    }

    /**
     * @dev Removes a ComponentFieldId item from the set if it exists
     * @notice Order is not preserved when removing items for gas efficiency
     */
    function remove(DatastoreSetIdComponentField setId, ComponentLib.ComponentFieldId item) external {
        PackedSet storage set = _componentFieldSets[msg.sender][setId];
        uint256 indexPlusOne = set.indexOf[item];

        if (indexPlusOne > 0) {
            // Item exists
            uint256 indexToRemove = indexPlusOne - 1;
            uint256 lastIndex = set.length - 1;

            if (indexToRemove != lastIndex) {
                // Move the last item to the position of the item to remove
                ComponentLib.ComponentFieldId lastItem = _getAtIndex(set, lastIndex);
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

            emit RemoveComponentField(setId, item);
        }
    }

    /**
     * @dev Removes multiple ComponentFieldId items from the set
     * @notice Order is not preserved when removing items for gas efficiency
     */
    function removeBatch(DatastoreSetIdComponentField setId, ComponentLib.ComponentFieldId[] calldata items) external {
        PackedSet storage set = _componentFieldSets[msg.sender][setId];

        for (uint256 i; i < items.length; i++) {
            ComponentLib.ComponentFieldId item = items[i];
            uint256 indexPlusOne = set.indexOf[item];

            if (indexPlusOne > 0) {
                // Item exists
                uint256 indexToRemove = indexPlusOne - 1;
                uint256 lastIndex = set.length - 1;

                if (indexToRemove != lastIndex) {
                    // Move the last item to the position of the item to remove
                    ComponentLib.ComponentFieldId lastItem = _getAtIndex(set, lastIndex);
                    _setAtIndex(set, indexToRemove, lastItem);
                    set.indexOf[lastItem] = indexToRemove + 1;
                }

                // Clear the last position and reduce length
                _clearAtIndex(set, lastIndex);
                set.length--;
                delete set.indexOf[item];

                emit RemoveComponentField(setId, item);
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
    function _getAtIndex(PackedSet storage set, uint256 index) private view returns (ComponentLib.ComponentFieldId) {
        require(index < set.length, DatastoreSetComponentField_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        return _unpackComponentField(set.data[slotIndex], positionInSlot);
    }

    /**
     * @dev Internal function to set item at specific index
     */
    function _setAtIndex(PackedSet storage set, uint256 index, ComponentLib.ComponentFieldId value) private {
        require(index < set.length, DatastoreSetComponentField_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        set.data[slotIndex] = _packComponentField(set.data[slotIndex], positionInSlot, value);
    }

    /**
     * @dev Internal function to clear item at specific index (set to 0)
     */
    function _clearAtIndex(PackedSet storage set, uint256 index) private {
        require(index < set.length, DatastoreSetComponentField_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        set.data[slotIndex] =
            _packComponentField(set.data[slotIndex], positionInSlot, ComponentLib.ComponentFieldId.wrap(0));
    }

    /**
     * @dev Checks if the set contains a specific ComponentFieldId item
     */
    function contains(address datastoreSetOwner, DatastoreSetIdComponentField setId, ComponentLib.ComponentFieldId item)
        public
        view
        returns (bool)
    {
        return _componentFieldSets[datastoreSetOwner][setId].indexOf[item] > 0;
    }

    /**
     * @dev Returns the number of items in the set
     */
    function length(address datastoreSetOwner, DatastoreSetIdComponentField setId) external view returns (uint256) {
        return _componentFieldSets[datastoreSetOwner][setId].length;
    }

    /**
     * @dev Returns the item at the specified index
     */
    function at(address datastoreSetOwner, DatastoreSetIdComponentField setId, uint256 index)
        external
        view
        returns (ComponentLib.ComponentFieldId item)
    {
        PackedSet storage set = _componentFieldSets[datastoreSetOwner][setId];
        return _getAtIndex(set, index);
    }

    /**
     * @dev Returns all items in the set
     */
    function getAll(address datastoreSetOwner, DatastoreSetIdComponentField setId)
        external
        view
        returns (ComponentLib.ComponentFieldId[] memory items)
    {
        PackedSet storage set = _componentFieldSets[datastoreSetOwner][setId];
        items = new ComponentLib.ComponentFieldId[](set.length);

        for (uint256 i; i < set.length; i++) {
            items[i] = _getAtIndex(set, i);
        }

        return items;
    }

    /**
     * @dev Returns a range of items from the set
     */
    function getFrom(address datastoreSetOwner, DatastoreSetIdComponentField setId, uint256 index, uint256 count)
        public
        view
        returns (ComponentLib.ComponentFieldId[] memory items)
    {
        PackedSet storage set = _componentFieldSets[datastoreSetOwner][setId];
        uint256 totalLength = set.length;

        if (index >= totalLength) {
            return new ComponentLib.ComponentFieldId[](0);
        }
        if (index + count > totalLength) {
            count = totalLength - index;
        }

        items = new ComponentLib.ComponentFieldId[](count);
        for (uint256 i; i < count; i++) {
            items[i] = _getAtIndex(set, index + i);
        }

        return items;
    }

    /**
     * @dev Returns the last N items from the set
     */
    function getLast(address datastoreSetOwner, DatastoreSetIdComponentField setId, uint256 count)
        external
        view
        returns (ComponentLib.ComponentFieldId[] memory items)
    {
        PackedSet storage set = _componentFieldSets[datastoreSetOwner][setId];
        uint256 totalLength = set.length;

        if (totalLength < count) {
            count = totalLength;
        }

        return getFrom(datastoreSetOwner, setId, totalLength - count, count);
    }
}
