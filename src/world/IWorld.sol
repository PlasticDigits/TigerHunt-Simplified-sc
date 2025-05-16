// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
// World interface definitions and types
pragma solidity ^0.8.30;

import {Point3D} from "../lib/Point3DLib.sol";

type TileID is bytes32;

type WorldGeometryKey is bytes32;

interface IWorld {
    error InvalidFace();
    error InvalidTile();
    error InvalidCoordinate();

    function GEOMETRY_KEY() external view returns (WorldGeometryKey);

    function isValidTile(TileID tile) external view returns (bool);

    function getNeighbors(TileID tile) external view returns (TileID[] memory);

    function isNeighboring(TileID tileA, TileID tileB) external view returns (bool);

    function getTilePoint3D(TileID tile) external view returns (Point3D memory);
}
