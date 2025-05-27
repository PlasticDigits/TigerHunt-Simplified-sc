// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {EntityLib} from "../lib/EntityLib.sol";

type ComponentId is uint16;

/**
 * @title IComponent
 * @dev Base interface for all components in the ECS system
 */
interface IComponent {
    /**
     * @dev Returns the component type identifier
     */
    function getComponentId() external pure returns (ComponentId);

    /**
     * @dev Checks if an entity has this component
     * @param entityId The entity to check
     * @return True if the entity has this component
     */
    function hasComponent(EntityLib.EntityId entityId) external view returns (bool);

    /**
     * @dev Removes this component from an entity
     * @param entityId The entity to remove the component from
     */
    function removeComponent(EntityLib.EntityId entityId) external;
}
