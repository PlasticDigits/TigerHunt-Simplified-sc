// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {Ascii6Lib} from "./Ascii6Lib.sol";

/**
 * @title LogbookLib
 * @dev Library for managing LogbookAscii6 data structures
 * Handles efficient storage and retrieval of ASCII6 encoded data in bytes32 arrays
 */
library LogbookLib {
    using Ascii6Lib for bytes;

    // Constants for ASCII6 storage efficiency
    uint8 private constant CHARS_PER_BYTES32 = 42; // 256 bits ÷ 6 bits per char = 42.67, rounded down
    uint8 private constant BITS_PER_CHAR = 6; // Each ASCII6 character uses 6 bits
    uint8 private constant CHAR_BITMASK = 0x3F; // 6-bit mask (111111 in binary) for extracting single char

    struct LogbookAscii6 {
        uint8 lastElementCharCount; // Number of ASCII6 chars in the last bytes32 element (max 42)
        bytes32[] data;
    }

    /**
     * @dev Append ASCII6 data to LogbookAscii6 struct
     * @param logbook The LogbookAscii6 struct to append to
     * @param ascii6Data The ASCII6 data to append
     */
    function appendToLogbook(LogbookAscii6 storage logbook, bytes memory ascii6Data) internal {
        uint256 dataIndex = 0;

        while (dataIndex < ascii6Data.length) {
            if (logbook.data.length == 0 || logbook.lastElementCharCount == CHARS_PER_BYTES32) {
                logbook.data.push(bytes32(0));
                logbook.lastElementCharCount = 0;
            }

            uint256 remainingSpace = CHARS_PER_BYTES32 - logbook.lastElementCharCount;
            uint256 charsToAdd = ascii6Data.length - dataIndex;
            if (charsToAdd > remainingSpace) {
                charsToAdd = remainingSpace;
            }

            bytes32 currentElement = logbook.data[logbook.data.length - 1];
            currentElement =
                _packCharsIntoBytes32(currentElement, ascii6Data, dataIndex, charsToAdd, logbook.lastElementCharCount);

            logbook.data[logbook.data.length - 1] = currentElement;
            logbook.lastElementCharCount += uint8(charsToAdd);
            dataIndex += charsToAdd;
        }
    }

    /**
     * @dev Append UTF-8 string directly to LogbookAscii6 struct
     * @param logbook The LogbookAscii6 struct to append to
     * @param utf8String The UTF-8 string to convert and append
     */
    function appendStringToLogbook(LogbookAscii6 storage logbook, string memory utf8String) internal {
        bytes memory ascii6Data = Ascii6Lib.utf8ToAscii6(utf8String);
        appendToLogbook(logbook, ascii6Data);
    }

    /**
     * @dev Pack characters into bytes32
     */
    function _packCharsIntoBytes32(
        bytes32 currentElement,
        bytes memory ascii6Data,
        uint256 dataIndex,
        uint256 charsToAdd,
        uint256 startPosition
    ) private pure returns (bytes32) {
        for (uint256 i = 0; i < charsToAdd; i++) {
            uint8 charValue = uint8(ascii6Data[dataIndex + i]);
            uint256 bitPosition = (startPosition + i) * BITS_PER_CHAR;
            bytes32 mask = bytes32(uint256(CHAR_BITMASK) << (256 - bitPosition - BITS_PER_CHAR));
            currentElement =
                (currentElement & ~mask) | (bytes32(uint256(charValue)) << (256 - bitPosition - BITS_PER_CHAR));
        }
        return currentElement;
    }

    /**
     * @dev Convert LogbookAscii6 to UTF-8 string
     * @param logbook The LogbookAscii6 struct to convert
     * @return utf8String The decoded UTF-8 string
     */
    function logbookToUtf8(LogbookAscii6 storage logbook) internal view returns (string memory utf8String) {
        if (logbook.data.length == 0) return "";

        uint256 totalChars = (logbook.data.length - 1) * CHARS_PER_BYTES32 + logbook.lastElementCharCount;
        bytes memory ascii6Data = new bytes(totalChars);
        uint256 charIndex = 0;

        for (uint256 i = 0; i < logbook.data.length; i++) {
            bytes32 element = logbook.data[i];
            uint256 charsInElement = (i == logbook.data.length - 1) ? logbook.lastElementCharCount : CHARS_PER_BYTES32;

            for (uint256 j = 0; j < charsInElement; j++) {
                uint256 bitPosition = j * BITS_PER_CHAR;
                uint8 charValue = uint8((uint256(element) >> (256 - bitPosition - BITS_PER_CHAR)) & CHAR_BITMASK);
                ascii6Data[charIndex] = bytes1(charValue);
                charIndex++;
            }
        }

        return Ascii6Lib.ascii6ToUtf8(ascii6Data);
    }

    /**
     * @dev Get the total number of characters in LogbookAscii6
     * @param logbook The LogbookAscii6 struct
     * @return totalChars The total number of ASCII6 characters
     */
    function getLogbookCharCount(LogbookAscii6 storage logbook) internal view returns (uint256 totalChars) {
        if (logbook.data.length == 0) return 0;
        return (logbook.data.length - 1) * CHARS_PER_BYTES32 + logbook.lastElementCharCount;
    }

    /**
     * @dev Clear all data from LogbookAscii6
     * @param logbook The LogbookAscii6 struct to clear
     */
    function clearLogbook(LogbookAscii6 storage logbook) internal {
        delete logbook.data;
        logbook.lastElementCharCount = 0;
    }

    /**
     * @dev Get a specific page of the logbook as UTF-8 string
     * @param logbook The LogbookAscii6 struct to read from
     * @param pageIndex The index of the bytes32 element to read
     * @return pageContent The UTF-8 string content of the page
     */
    function getLogbookPage(LogbookAscii6 storage logbook, uint256 pageIndex)
        internal
        view
        returns (string memory pageContent)
    {
        if (pageIndex >= logbook.data.length) return "";

        bytes32 element = logbook.data[pageIndex];
        uint256 charsInElement =
            (pageIndex == logbook.data.length - 1) ? logbook.lastElementCharCount : CHARS_PER_BYTES32;

        bytes memory ascii6Data = new bytes(charsInElement);

        for (uint256 j = 0; j < charsInElement; j++) {
            uint256 bitPosition = j * BITS_PER_CHAR;
            uint8 charValue = uint8((uint256(element) >> (256 - bitPosition - BITS_PER_CHAR)) & CHAR_BITMASK);
            ascii6Data[j] = bytes1(charValue);
        }

        return Ascii6Lib.ascii6ToUtf8(ascii6Data);
    }

    /**
     * @dev Get the number of pages in the logbook
     * @param logbook The LogbookAscii6 struct
     * @return pageCount The number of bytes32 elements (pages) in the logbook
     */
    function getLogbookPageCount(LogbookAscii6 storage logbook) internal view returns (uint256 pageCount) {
        return logbook.data.length;
    }
}
