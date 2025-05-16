// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

import {SD59x18} from "@prb-math/SD59x18.sol";

struct Point3D {
    SD59x18 x;
    SD59x18 y;
    SD59x18 z;
}

/**
 * @title Point3DLib
 * @dev Library for operations on Point3D structures including 3D simplex noise generation.
 */
library Point3DLib {
    // Default cell width for noise functions
    SD59x18 internal constant DEFAULT_CELL_WIDTH = SD59x18.wrap(1e18); // 1.0

    function wrap(SD59x18 x, SD59x18 y, SD59x18 z) internal pure returns (Point3D memory) {
        return Point3D(x, y, z);
    }

    function unwrap(Point3D memory point) internal pure returns (SD59x18, SD59x18, SD59x18) {
        return (point.x, point.y, point.z);
    }

    function distanceSquared(Point3D memory a, Point3D memory b) internal pure returns (SD59x18) {
        // So we dont need to use sqrt.
        // Here we use the library for SD59x18 for math.
        SD59x18 dx = a.x - b.x;
        SD59x18 dy = a.y - b.y;
        SD59x18 dz = a.z - b.z;
        return dx * dx + dy * dy + dz * dz;
    }

    function hash(Point3D memory point, bytes32 seed) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(seed, point.x, point.y, point.z));
    }

    /**
     * @notice Gets the minimum corner (+x, +y, +z) of the cube containing the point
     * @dev Each
     * @param point The point to find the containing cube for
     * @param cellWidth The grid cell size
     * @return The minimum corner of the containing cube
     */
    function getGridCubeCornerMin(Point3D memory point, SD59x18 cellWidth) internal pure returns (Point3D memory) {
        // Floor coordinates to get the minimum corner based on cell width
        SD59x18 x0 = (point.x / cellWidth).floor() * cellWidth;
        SD59x18 y0 = (point.y / cellWidth).floor() * cellWidth;
        SD59x18 z0 = (point.z / cellWidth).floor() * cellWidth;

        return Point3D(x0, y0, z0);
    }

    function getGridCubeCorners(Point3D memory point, SD59x18 cellWidth)
        internal
        pure
        returns (Point3D[8] memory corners)
    {
        // Initialize fixed-size array directly
        Point3D memory minCorner = getGridCubeCornerMin(point, cellWidth);
        //bottom 4 corners (-z) in clockwise order
        corners[0] = minCorner;
        corners[1] = Point3D(minCorner.x + cellWidth, minCorner.y, minCorner.z);
        corners[2] = Point3D(minCorner.x + cellWidth, minCorner.y + cellWidth, minCorner.z);
        corners[3] = Point3D(minCorner.x, minCorner.y + cellWidth, minCorner.z);
        //top 4 corners (+z) in clockwise order
        corners[4] = Point3D(minCorner.x, minCorner.y, minCorner.z + cellWidth);
        corners[5] = Point3D(minCorner.x + cellWidth, minCorner.y, minCorner.z + cellWidth);
        corners[6] = Point3D(minCorner.x + cellWidth, minCorner.y + cellWidth, minCorner.z + cellWidth);
        corners[7] = Point3D(minCorner.x, minCorner.y + cellWidth, minCorner.z + cellWidth);
        return corners;
    }

    function lerp(SD59x18 a, SD59x18 b, SD59x18 t) internal pure returns (SD59x18) {
        return ((b - a) * t) + a;
    }

    function lerp(Point3D memory a, Point3D memory b, SD59x18 t) internal pure returns (Point3D memory) {
        return Point3D(lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t));
    }

    // Normalize a hash value to a floating point between -1 and 1
    function normalizeHash(bytes32 h) internal pure returns (SD59x18) {
        // Convert to a number between -1e18 and 1e18
        int256 value = (int256(uint256(h) % 2e18) - 1e18);
        return SD59x18.wrap(value);
    }

    // 3D hash noise, discretize space into grid then interpolate between random values at the grid points.
    function noiseHash3D(Point3D memory point, bytes32 seed, SD59x18 cellWidth) internal pure returns (SD59x18) {
        // Get the cube corners
        Point3D[8] memory cubeCorners = getGridCubeCorners(point, cellWidth);
        // Get the random values at the cube corners
        SD59x18[8] memory cubeCornerValues;
        for (uint256 i = 0; i < 8; i++) {
            cubeCornerValues[i] = normalizeHash(Point3DLib.hash(cubeCorners[i], seed));
        }

        // Get the interpolation factors
        SD59x18[3] memory interpolationFactors;
        interpolationFactors[0] = (point.x - cubeCorners[0].x) / cellWidth;
        interpolationFactors[1] = (point.y - cubeCorners[0].y) / cellWidth;
        interpolationFactors[2] = (point.z - cubeCorners[0].z) / cellWidth;

        // 1. Interpolate along the X axis, for both the bottom and top of the cube
        SD59x18 bottomX1 = lerp(cubeCornerValues[0], cubeCornerValues[1], interpolationFactors[0]);
        SD59x18 bottomX2 = lerp(cubeCornerValues[3], cubeCornerValues[2], interpolationFactors[0]);
        SD59x18 topX1 = lerp(cubeCornerValues[4], cubeCornerValues[5], interpolationFactors[0]);
        SD59x18 topX2 = lerp(cubeCornerValues[7], cubeCornerValues[6], interpolationFactors[0]);

        // 2. Interpolate the above results along Y for both faces
        SD59x18 bottomFace = lerp(bottomX1, bottomX2, interpolationFactors[1]);
        SD59x18 topFace = lerp(topX1, topX2, interpolationFactors[1]);

        // 3. Interpolate the above results along Z for the final value
        SD59x18 value = lerp(bottomFace, topFace, interpolationFactors[2]);

        return value;
    }
    /**
     * @notice Generates 3D fractal noise (FBM - Fractional Brownian Motion)
     * @param point The input point in 3D space
     * @param seed Random seed for the noise
     * @param octaves Number of noise layers to combine
     * @param persistence Controls how quickly amplitude diminishes for higher octaves
     * @param cellWidth Base cell width for the grid
     * @return SD59x18 The fractal noise value, typically in range [-1, 1]
     */

    function noiseValue3DFractal(
        Point3D memory point,
        bytes32 seed,
        uint256 octaves,
        SD59x18 persistence,
        SD59x18 cellWidth
    ) internal pure returns (SD59x18) {
        SD59x18 total = SD59x18.wrap(0);
        SD59x18 frequency = SD59x18.wrap(1e18); // Start with frequency 1.0
        SD59x18 amplitude = SD59x18.wrap(1e18); // Start with amplitude 1.0
        SD59x18 maxValue = SD59x18.wrap(0); // Used for normalizing the result

        // Add successive layers of noise
        for (uint256 i = 0; i < octaves; i++) {
            // Scale the coordinates based on frequency
            Point3D memory scaledPoint = Point3D(point.x * frequency, point.y * frequency, point.z * frequency);

            // Add scaled noise value
            total = total + (noiseHash3D(scaledPoint, seed, cellWidth) * amplitude);

            // Track maximum possible amplitude for normalization
            maxValue = maxValue + amplitude;

            // Increase frequency for next octave
            frequency = frequency * SD59x18.wrap(2e18); // Double the frequency each octave

            // Decrease amplitude based on persistence
            amplitude = amplitude * persistence;
        }

        // Normalize the result to keep output roughly in the range [-1, 1]
        if (maxValue.unwrap() > 0) {
            total = total / maxValue;
        }

        return total;
    }
}
