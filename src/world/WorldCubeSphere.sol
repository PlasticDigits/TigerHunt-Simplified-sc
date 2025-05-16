// SPDX-License-Identifier: GPL-3.0
// Authored for cube-based spherical world projection
pragma solidity ^0.8.30;

import {TileID, Point3D} from "./IWorld.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IWorld, WorldGeometryKey} from "./IWorld.sol";
import {SD59x18} from "@prb-math/SD59x18.sol";
/**
 * @title WorldCubeSphere
 * @dev A world represented as a cube with 6 faces, where each face is a grid of tiles.
 *   FaceIndex is the face ID (0-5):
 *     - 0: Front
 *     - 1: Right
 *     - 2: Back
 *     - 3: Left
 *     - 4: Top
 *     - 5: Bottom
 */

contract WorldCubeSphere is IWorld {
    using SafeCast for uint256;
    using SafeCast for int256;

    uint32 public immutable GRID_SIZE; // Size of each face grid (e.g., 16 means 16x16 grid)
    uint32 public constant FACE_COUNT = 6;

    WorldGeometryKey public constant GEOMETRY_KEY = WorldGeometryKey.wrap(keccak256("CubeSphere"));

    // Cardinal directions for grid movement
    // 0: Right, 1: Down, 2: Left, 3: Up
    int8[2][4] private directions = [
        [int8(1), int8(0)], // Right
        [int8(0), int8(1)], // Down
        [int8(-1), int8(0)], // Left
        [int8(0), int8(-1)] // Up
    ];

    // Define face edges: [faceID, rotation]
    // Rotation is how many 90-degree clockwise rotations to apply when crossing
    struct FaceEdge {
        uint32 neighborFace; // The face connected to this edge
        uint8 rotation; // Number of 90-degree clockwise rotations (0-3)
    }

    struct CubeSphereCoordinates {
        uint32 x;
        uint32 y;
        uint32 faceIndex;
    }

    // Edge order: Right, Down, Left, Up (matching directions array)
    FaceEdge[4][6] public faceEdges;

    constructor(uint32 gridSize) {
        GRID_SIZE = gridSize;

        // Set up the cube connectivity
        // Face 0 (Front) connections
        faceEdges[0][0] = FaceEdge(1, 0); // Right edge to Right face
        faceEdges[0][1] = FaceEdge(5, 0); // Bottom edge to Bottom face
        faceEdges[0][2] = FaceEdge(3, 0); // Left edge to Left face
        faceEdges[0][3] = FaceEdge(4, 2); // Top edge to Top face (rotated 180°)

        // Face 1 (Right) connections
        faceEdges[1][0] = FaceEdge(2, 0); // Right edge to Back face
        faceEdges[1][1] = FaceEdge(5, 1); // Bottom edge to Bottom face (rotated 90°)
        faceEdges[1][2] = FaceEdge(0, 0); // Left edge to Front face
        faceEdges[1][3] = FaceEdge(4, 1); // Top edge to Top face (rotated 90°)

        // Face 2 (Back) connections
        faceEdges[2][0] = FaceEdge(3, 0); // Right edge to Left face
        faceEdges[2][1] = FaceEdge(5, 2); // Bottom edge to Bottom face (rotated 180°)
        faceEdges[2][2] = FaceEdge(1, 0); // Left edge to Right face
        faceEdges[2][3] = FaceEdge(4, 2); // Top edge to Top face (rotated 180°)

        // Face 3 (Left) connections
        faceEdges[3][0] = FaceEdge(0, 0); // Right edge to Front face
        faceEdges[3][1] = FaceEdge(5, 3); // Bottom edge to Bottom face (rotated 270°)
        faceEdges[3][2] = FaceEdge(2, 0); // Left edge to Back face
        faceEdges[3][3] = FaceEdge(4, 3); // Top edge to Top face (rotated 270°)

        // Face 4 (Top) connections
        faceEdges[4][0] = FaceEdge(1, 3); // Right edge to Right face (rotated 270°)
        faceEdges[4][1] = FaceEdge(0, 2); // Bottom edge to Front face (rotated 180°)
        faceEdges[4][2] = FaceEdge(3, 1); // Left edge to Left face (rotated 90°)
        faceEdges[4][3] = FaceEdge(2, 2); // Top edge to Back face (rotated 180°)

        // Face 5 (Bottom) connections
        faceEdges[5][0] = FaceEdge(1, 1); // Right edge to Right face (rotated 90°)
        faceEdges[5][1] = FaceEdge(2, 2); // Bottom edge to Back face (rotated 180°)
        faceEdges[5][2] = FaceEdge(3, 3); // Left edge to Left face (rotated 270°)
        faceEdges[5][3] = FaceEdge(0, 0); // Top edge to Front face (no rotation)
    }

    /**
     * @dev Checks if a tile is valid (within grid bounds)
     * @param tile The tile to check
     * @return bool True if the tile is valid
     */
    function isValidTile(TileID tile) public view returns (bool) {
        CubeSphereCoordinates memory coordinates = convertTileIDToCubeSphereCoordinates(tile);
        if (coordinates.faceIndex >= FACE_COUNT) {
            return false;
        }

        return (coordinates.x < GRID_SIZE && coordinates.y < GRID_SIZE);
    }

    /**
     * @dev Gets neighboring tiles in all four cardinal directions
     * @param tile The center tile
     * @return neighbors Array of 4 neighboring tiles (Right, Down, Left, Up)
     */
    function getNeighbors(TileID tile) public view returns (TileID[] memory) {
        require(isValidTile(tile), InvalidTile());
        CubeSphereCoordinates memory coordinates = convertTileIDToCubeSphereCoordinates(tile);

        TileID[] memory neighbors = new TileID[](4);
        int256 x = uint256(coordinates.x).toInt256();
        int256 y = uint256(coordinates.y).toInt256();

        for (uint8 i = 0; i < 4; i++) {
            int256 nx = x + int256(directions[i][0]);
            int256 ny = y + int256(directions[i][1]);

            // Check if neighbor is on the same face
            if (nx >= 0 && nx < int256(uint256(GRID_SIZE)) && ny >= 0 && ny < int256(uint256(GRID_SIZE))) {
                neighbors[i] = convertCubeSphereCoordinatesToTileID(
                    CubeSphereCoordinates(nx.toUint256().toUint32(), ny.toUint256().toUint32(), coordinates.faceIndex)
                );
            } else {
                // Handle edge crossing
                neighbors[i] = getEdgeCrossingNeighbor(tile, i);
            }
        }

        return neighbors;
    }

    /**
     * @dev Calculates the neighboring tile when crossing an edge
     * @param tile The current tile
     * @param directionIndex The direction index (0-3: Right, Down, Left, Up)
     * @return The neighboring tile on the adjacent face
     */
    function getEdgeCrossingNeighbor(TileID tile, uint8 directionIndex) internal view returns (TileID) {
        CubeSphereCoordinates memory coordinates = convertTileIDToCubeSphereCoordinates(tile);
        uint32 currentFace = coordinates.faceIndex;
        FaceEdge memory edge = faceEdges[currentFace][directionIndex];
        uint32 newFace = edge.neighborFace;
        uint8 rotation = edge.rotation;

        uint32 newX;
        uint32 newY;

        // Calculate the position on the new face based on direction and rotation
        uint32 gridSizeMinusOne = GRID_SIZE - 1;

        // Determine offset along the edge
        uint32 offset;
        if (directionIndex == 0) {
            // Right edge
            offset = coordinates.y;
            newX = 0;
            newY = offset;
        } else if (directionIndex == 1) {
            // Bottom edge
            offset = gridSizeMinusOne - coordinates.x;
            newX = offset;
            newY = 0;
        } else if (directionIndex == 2) {
            // Left edge
            offset = gridSizeMinusOne - coordinates.y;
            newX = gridSizeMinusOne;
            newY = offset;
        } else {
            // Top edge
            offset = coordinates.x;
            newX = offset;
            newY = gridSizeMinusOne;
        }

        // Apply rotation to the coordinates
        for (uint8 i = 0; i < rotation; i++) {
            uint32 temp = newX;
            newX = newY;
            newY = gridSizeMinusOne - temp;
        }

        return convertCubeSphereCoordinatesToTileID(CubeSphereCoordinates(newX, newY, newFace));
    }

    /**
     * @dev Checks if two tiles are neighbors
     * @param tileA First tile
     * @param tileB Second tile
     * @return True if tiles are neighbors
     */
    function isNeighboring(TileID tileA, TileID tileB) public view returns (bool) {
        TileID[] memory neighbors = getNeighbors(tileA);
        for (uint8 i = 0; i < 4; i++) {
            if (TileID.unwrap(neighbors[i]) == TileID.unwrap(tileB)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Converts the cubic coordinates to spherical coordinates
     * @param tile The tile in cubic representation
     * @return point3D The 3D point coordinates on the sphere
     */
    function getTilePoint3D(TileID tile) public view returns (Point3D memory) {
        CubeSphereCoordinates memory coordinates = convertTileIDToCubeSphereCoordinates(tile);
        // Normalize coordinates to [-1e6, 1e6] range
        int256 gridSize = int256(uint256(GRID_SIZE));
        int256 u = (2 * int256(uint256(coordinates.x)) + 1 - gridSize) / gridSize;
        int256 v = (2 * int256(uint256(coordinates.y)) + 1 - gridSize) / gridSize;

        // Convert cube face to 3D coordinates
        int256 x;
        int256 y;
        int256 z;

        if (coordinates.faceIndex == 0) {
            // Front face
            x = 1;
            y = v;
            z = -u;
        } else if (coordinates.faceIndex == 1) {
            // Right face
            x = u;
            y = v;
            z = -1;
        } else if (coordinates.faceIndex == 2) {
            // Back face
            x = -1;
            y = v;
            z = u;
        } else if (coordinates.faceIndex == 3) {
            // Left face
            x = -u;
            y = v;
            z = 1;
        } else if (coordinates.faceIndex == 4) {
            // Top face
            x = u;
            y = 1;
            z = v;
        } else {
            // Bottom face
            x = u;
            y = -1;
            z = -v;
        }

        // Project cube coordinates to sphere
        int256 length = int256(Math.sqrt(uint256((x * x + y * y + z * z) * 1e6))) / 1e3;
        x = (x * 1e6) / length;
        y = (y * 1e6) / length;
        z = (z * 1e6) / length;

        // Convert to SD59x18 format
        SD59x18 xSD = SD59x18.wrap(x * 1e18);
        SD59x18 ySD = SD59x18.wrap(y * 1e18);
        SD59x18 zSD = SD59x18.wrap(z * 1e18);

        return Point3D(xSD, ySD, zSD);
    }

    function convertTileIDToCubeSphereCoordinates(TileID tile) public view returns (CubeSphereCoordinates memory) {
        bytes32 raw = TileID.unwrap(tile);
        // Extract x, y, and faceIndex from the bytes32
        // x and y are 16 bits each (0-65535), faceIndex is 8 bits (0-255)
        uint32 x = uint32(uint256(raw) >> 16) & 0xFFFF;
        uint32 y = uint32(uint256(raw)) & 0xFFFF;
        uint32 faceIndex = uint32(uint256(raw) >> 32) & 0xFF;

        require(x < GRID_SIZE, InvalidCoordinate());
        require(y < GRID_SIZE, InvalidCoordinate());
        require(faceIndex < FACE_COUNT, InvalidCoordinate());

        return CubeSphereCoordinates(x, y, faceIndex);
    }

    function convertCubeSphereCoordinatesToTileID(CubeSphereCoordinates memory coordinates)
        public
        view
        returns (TileID)
    {
        require(coordinates.x < GRID_SIZE, InvalidCoordinate());
        require(coordinates.y < GRID_SIZE, InvalidCoordinate());
        require(coordinates.faceIndex < FACE_COUNT, InvalidCoordinate());

        // Pack x, y, and faceIndex into bytes32
        // x and y are 16 bits each, faceIndex is 8 bits
        bytes32 packed =
            bytes32((uint256(coordinates.faceIndex) << 32) | (uint256(coordinates.x) << 16) | uint256(coordinates.y));

        return TileID.wrap(packed);
    }
}
