// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {EntityLib} from "../lib/EntityLib.sol";
import {IComponent} from "./IComponent.sol";

/**
 * @title IComponentRegistry
 * @dev Interface for managing component registration and lookup
 */
interface IComponentRegistry {
    /**
     * @dev Emitted when a component is registered
     * @param componentType The type identifier of the component
     * @param componentAddress The address of the component contract
     */
    event ComponentRegistered(bytes32 indexed componentType, address indexed componentAddress);

    /**
     * @dev Emitted when a component is unregistered
     * @param componentType The type identifier of the component
     */
    event ComponentUnregistered(bytes32 indexed componentType);

    /**
     * @dev Registers a component contract
     * @param component The component contract to register
     */
    function registerComponent(IComponent component) external;

    /**
     * @dev Unregisters a component by type
     * @param componentType The type identifier of the component to unregister
     */
    function unregisterComponent(bytes32 componentType) external;

    /**
     * @dev Gets a component contract by type
     * @param componentType The type identifier of the component
     * @return The component contract address
     */
    function getComponent(bytes32 componentType) external view returns (IComponent);

    /**
     * @dev Checks if a component type is registered
     * @param componentType The type identifier to check
     * @return True if the component type is registered
     */
    function isComponentRegistered(bytes32 componentType) external view returns (bool);

    /**
     * @dev Gets all registered component types
     * @return Array of registered component type identifiers
     */
    function getRegisteredComponentTypes() external view returns (bytes32[] memory);
}
