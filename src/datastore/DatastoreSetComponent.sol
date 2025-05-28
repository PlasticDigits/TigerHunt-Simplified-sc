// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {ComponentLib} from "../lib/ComponentLib.sol";

type DatastoreSetIdComponent is bytes32;

/**
 * @title DatastoreSetComponent
 * @dev Allows a contract to manage multiple sets of ComponentId values packed efficiently into bytes32 arrays
 * @notice Sets are meant to be owned by a permissioned contract, not a user, since the owner is msg.sender
 * @notice Packs 16 ComponentId values (2 bytes each) into each bytes32 (32 bytes total)
 */
contract DatastoreSetComponent {
    uint256 private constant ITEMS_PER_SLOT = 16; // 16 ComponentIds per bytes32
    uint256 private constant COMPONENT_SIZE = 2; // 2 bytes per ComponentId

    struct PackedSet {
        bytes32[] data; // Packed data storage
        uint256 length; // Total number of ComponentId items stored
        mapping(ComponentLib.ComponentId => uint256) indexOf; // item => index + 1
    }

    // Registry for ComponentId sets - msg.sender => setId => set
    mapping(address owner => mapping(DatastoreSetIdComponent setId => PackedSet set)) private _componentSets;

    // Events
    event AddComponent(DatastoreSetIdComponent setId, ComponentLib.ComponentId data);
    event RemoveComponent(DatastoreSetIdComponent setId, ComponentLib.ComponentId data);

    // Errors
    error DatastoreSetComponent_IndexOutOfBounds();
    error DatastoreSetComponent_PositionOutOfBounds();

    /**
     * @dev Packs a ComponentId value into a bytes32 slot at the specified position
     * @param slot The current bytes32 slot
     * @param position Position within the slot (0-15)
     * @param value The ComponentId value to pack
     * @return The updated bytes32 slot
     */
    function _packComponent(bytes32 slot, uint8 position, ComponentLib.ComponentId value)
        private
        pure
        returns (bytes32)
    {
        require(position < ITEMS_PER_SLOT, DatastoreSetComponent_PositionOutOfBounds());
        uint256 shift = position * 16; // 16 bits per ComponentId
        uint256 mask = ~(uint256(0xFFFF) << shift);
        return bytes32((uint256(slot) & mask) | (uint256(ComponentLib.ComponentId.unwrap(value)) << shift));
    }

    /**
     * @dev Extracts a ComponentId value from a bytes32 slot at the specified position
     * @param slot The bytes32 slot to extract from
     * @param position Position within the slot (0-15)
     * @return The extracted ComponentId value
     */
    function _unpackComponent(bytes32 slot, uint8 position) private pure returns (ComponentLib.ComponentId) {
        require(position < ITEMS_PER_SLOT, DatastoreSetComponent_PositionOutOfBounds());
        uint256 shift = position * 16; // 16 bits per ComponentId
        return ComponentLib.ComponentId.wrap(uint16((uint256(slot) >> shift) & 0xFFFF));
    }

    /**
     * @dev Adds a ComponentId item to the set if it doesn't already exist
     */
    function add(DatastoreSetIdComponent setId, ComponentLib.ComponentId item) external {
        PackedSet storage set = _componentSets[msg.sender][setId];

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
            set.data[slotIndex] = _packComponent(set.data[slotIndex], positionInSlot, item);
            set.length++;
            set.indexOf[item] = newIndex + 1; // Store index + 1

            emit AddComponent(setId, item);
        }
    }

    /**
     * @dev Adds multiple ComponentId items to the set
     */
    function addBatch(DatastoreSetIdComponent setId, ComponentLib.ComponentId[] calldata items) external {
        PackedSet storage set = _componentSets[msg.sender][setId];

        for (uint256 i; i < items.length; i++) {
            ComponentLib.ComponentId item = items[i];

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
                set.data[slotIndex] = _packComponent(set.data[slotIndex], positionInSlot, item);
                set.length++;
                set.indexOf[item] = newIndex + 1; // Store index + 1

                emit AddComponent(setId, item);
            }
        }
    }

    /**
     * @dev Removes a ComponentId item from the set if it exists
     * @notice Order is not preserved when removing items for gas efficiency
     */
    function remove(DatastoreSetIdComponent setId, ComponentLib.ComponentId item) external {
        PackedSet storage set = _componentSets[msg.sender][setId];
        uint256 indexPlusOne = set.indexOf[item];

        if (indexPlusOne > 0) {
            // Item exists
            uint256 indexToRemove = indexPlusOne - 1;
            uint256 lastIndex = set.length - 1;

            if (indexToRemove != lastIndex) {
                // Move the last item to the position of the item to remove
                ComponentLib.ComponentId lastItem = _getAtIndex(set, lastIndex);
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

            emit RemoveComponent(setId, item);
        }
    }

    /**
     * @dev Removes multiple ComponentId items from the set
     * @notice Order is not preserved when removing items for gas efficiency
     */
    function removeBatch(DatastoreSetIdComponent setId, ComponentLib.ComponentId[] calldata items) external {
        PackedSet storage set = _componentSets[msg.sender][setId];

        for (uint256 i; i < items.length; i++) {
            ComponentLib.ComponentId item = items[i];
            uint256 indexPlusOne = set.indexOf[item];

            if (indexPlusOne > 0) {
                // Item exists
                uint256 indexToRemove = indexPlusOne - 1;
                uint256 lastIndex = set.length - 1;

                if (indexToRemove != lastIndex) {
                    // Move the last item to the position of the item to remove
                    ComponentLib.ComponentId lastItem = _getAtIndex(set, lastIndex);
                    _setAtIndex(set, indexToRemove, lastItem);
                    set.indexOf[lastItem] = indexToRemove + 1;
                }

                // Clear the last position and reduce length
                _clearAtIndex(set, lastIndex);
                set.length--;
                delete set.indexOf[item];

                emit RemoveComponent(setId, item);
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
    function _getAtIndex(PackedSet storage set, uint256 index) private view returns (ComponentLib.ComponentId) {
        require(index < set.length, DatastoreSetComponent_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        return _unpackComponent(set.data[slotIndex], positionInSlot);
    }

    /**
     * @dev Internal function to set item at specific index
     */
    function _setAtIndex(PackedSet storage set, uint256 index, ComponentLib.ComponentId value) private {
        require(index < set.length, DatastoreSetComponent_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        set.data[slotIndex] = _packComponent(set.data[slotIndex], positionInSlot, value);
    }

    /**
     * @dev Internal function to clear item at specific index (set to 0)
     */
    function _clearAtIndex(PackedSet storage set, uint256 index) private {
        require(index < set.length, DatastoreSetComponent_IndexOutOfBounds());
        uint256 slotIndex = index / ITEMS_PER_SLOT;
        uint8 positionInSlot = uint8(index % ITEMS_PER_SLOT);
        set.data[slotIndex] = _packComponent(set.data[slotIndex], positionInSlot, ComponentLib.ComponentId.wrap(0));
    }

    /**
     * @dev Checks if the set contains a specific ComponentId item
     */
    function contains(address datastoreSetOwner, DatastoreSetIdComponent setId, ComponentLib.ComponentId item)
        public
        view
        returns (bool)
    {
        return _componentSets[datastoreSetOwner][setId].indexOf[item] > 0;
    }

    /**
     * @dev Returns the number of items in the set
     */
    function length(address datastoreSetOwner, DatastoreSetIdComponent setId) external view returns (uint256) {
        return _componentSets[datastoreSetOwner][setId].length;
    }

    /**
     * @dev Returns the item at the specified index
     */
    function at(address datastoreSetOwner, DatastoreSetIdComponent setId, uint256 index)
        external
        view
        returns (ComponentLib.ComponentId item)
    {
        PackedSet storage set = _componentSets[datastoreSetOwner][setId];
        return _getAtIndex(set, index);
    }

    /**
     * @dev Returns all items in the set
     */
    function getAll(address datastoreSetOwner, DatastoreSetIdComponent setId)
        external
        view
        returns (ComponentLib.ComponentId[] memory items)
    {
        PackedSet storage set = _componentSets[datastoreSetOwner][setId];
        items = new ComponentLib.ComponentId[](set.length);

        for (uint256 i; i < set.length; i++) {
            items[i] = _getAtIndex(set, i);
        }

        return items;
    }

    /**
     * @dev Returns a range of items from the set
     */
    function getFrom(address datastoreSetOwner, DatastoreSetIdComponent setId, uint256 index, uint256 count)
        public
        view
        returns (ComponentLib.ComponentId[] memory items)
    {
        PackedSet storage set = _componentSets[datastoreSetOwner][setId];
        uint256 totalLength = set.length;

        if (index >= totalLength) {
            return new ComponentLib.ComponentId[](0);
        }
        if (index + count > totalLength) {
            count = totalLength - index;
        }

        items = new ComponentLib.ComponentId[](count);
        for (uint256 i; i < count; i++) {
            items[i] = _getAtIndex(set, index + i);
        }

        return items;
    }

    /**
     * @dev Returns the last N items from the set
     */
    function getLast(address datastoreSetOwner, DatastoreSetIdComponent setId, uint256 count)
        external
        view
        returns (ComponentLib.ComponentId[] memory items)
    {
        PackedSet storage set = _componentSets[datastoreSetOwner][setId];
        uint256 totalLength = set.length;

        if (totalLength < count) {
            count = totalLength;
        }

        return getFrom(datastoreSetOwner, setId, totalLength - count, count);
    }
}
