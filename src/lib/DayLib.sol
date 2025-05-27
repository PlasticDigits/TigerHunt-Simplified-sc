// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

/**
 * @title DayLib
 * @dev Library for converting timestamps to days since January 1, 2025 game start
 * @notice Uses uint16 for day representation (2 bytes) which lasts 179 years before overflow
 * @notice Allows overflows for immutable contract longevity - no date comparisons included
 */
library DayLib {
    /// @dev Timestamp for January 1, 2025 00:00:00 UTC (1735689600)
    uint64 private constant GAME_START_TIMESTAMP = 1735689600;

    type DayInGame is uint16;

    /**
     * @dev Converts a timestamp to days since January 1, 2025
     * @param timestamp The timestamp to convert (uint64)
     * @return day The number of days since game start (DayInGame)
     * @notice Uses unchecked arithmetic to allow overflow after 179 years
     * @notice No validation for timestamps before game start to handle overflow cases
     */
    function timestampToDay(uint64 timestamp) internal pure returns (DayInGame day) {
        unchecked {
            // Calculate seconds since game start (allows underflow/overflow)
            uint64 secondsSinceStart = timestamp - GAME_START_TIMESTAMP;

            // Convert to days and cast to uint16 (allows overflow)
            day = DayInGame.wrap(uint16(secondsSinceStart / 1 days));
        }
    }

    /**
     * @dev Returns the current timestamp converted to days since January 1, 2025
     * @return day The current day since game start (uint16)
     * @notice Uses block.timestamp and allows overflow after 179 years
     */
    function getCurrentDay() internal view returns (DayInGame day) {
        unchecked {
            // Get current timestamp and convert to uint64
            uint64 currentTimestamp = uint64(block.timestamp);

            // Convert to day using the same logic
            day = DayInGame.wrap(uint16(currentTimestamp / 1 days));
        }
    }

    /**
     * @dev Returns the game start timestamp
     * @return The timestamp for January 1, 2025 00:00:00 UTC
     */
    function getGameStartTimestamp() internal pure returns (uint64) {
        return GAME_START_TIMESTAMP;
    }
}
