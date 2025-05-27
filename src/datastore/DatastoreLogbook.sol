// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {Ascii6Lib} from "../lib/Ascii6Lib.sol";

type DatastoreLogbookId is uint16;

/**
 * @title DatastoreLogbook
 * @dev Allows a contract to manage multiple ASCII6-encoded logbooks
 * @notice Logbooks are meant to be owned by a permissioned contract, not a user, since the owner is msg.sender
 * Handles efficient storage and retrieval of ASCII6 encoded data in bytes32 arrays
 */
contract DatastoreLogbook {
    using Ascii6Lib for bytes;

    // Constants for ASCII6 storage efficiency
    uint8 private constant CHARS_PER_BYTES32 = 42; // 256 bits ÷ 6 bits per char = 42.67, rounded down
    uint8 private constant BITS_PER_CHAR = 6; // Each ASCII6 character uses 6 bits
    uint8 private constant CHAR_BITMASK = 0x3F; // 6-bit mask (111111 in binary) for extracting single char

    struct LogbookAscii6 {
        uint8 lastElementCharCount; // Number of ASCII6 chars in the last bytes32 element (max 42)
        bytes32[] data;
    }

    // Registry for logbooks - msg.sender => logbookId => logbook
    mapping(address datastoreLogbookOwner => mapping(DatastoreLogbookId logbookId => LogbookAscii6 logbook)) private
        _logbooks;

    // Events
    event AppendToLogbook(DatastoreLogbookId logbookId, string data);
    event ClearLogbook(DatastoreLogbookId logbookId);

    /**
     * @dev Append ASCII6 data to logbook
     * @param logbookId The ID of the logbook to append to
     * @param ascii6Data The ASCII6 data to append
     */
    function append(DatastoreLogbookId logbookId, bytes memory ascii6Data) public {
        LogbookAscii6 storage logbook = _logbooks[msg.sender][logbookId];
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

        emit AppendToLogbook(logbookId, Ascii6Lib.ascii6ToUtf8(ascii6Data));
    }

    /**
     * @dev Append UTF-8 string directly to logbook
     * @param logbookId The ID of the logbook to append to
     * @param utf8String The UTF-8 string to convert and append
     */
    function appendString(DatastoreLogbookId logbookId, string memory utf8String) external {
        append(logbookId, Ascii6Lib.utf8ToAscii6(utf8String));
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
     * @dev Convert logbook to UTF-8 string
     * @param datastoreLogbookOwner The owner of the logbook
     * @param logbookId The ID of the logbook to convert
     * @return utf8String The decoded UTF-8 string
     */
    function toUtf8(address datastoreLogbookOwner, DatastoreLogbookId logbookId)
        external
        view
        returns (string memory utf8String)
    {
        LogbookAscii6 storage logbook = _logbooks[datastoreLogbookOwner][logbookId];
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
     * @dev Get the total number of characters in logbook
     * @param datastoreLogbookOwner The owner of the logbook
     * @param logbookId The ID of the logbook
     * @return totalChars The total number of ASCII6 characters
     */
    function getCharCount(address datastoreLogbookOwner, DatastoreLogbookId logbookId)
        external
        view
        returns (uint256 totalChars)
    {
        LogbookAscii6 storage logbook = _logbooks[datastoreLogbookOwner][logbookId];
        if (logbook.data.length == 0) return 0;
        return (logbook.data.length - 1) * CHARS_PER_BYTES32 + logbook.lastElementCharCount;
    }

    /**
     * @dev Get a specific page of the logbook as UTF-8 string
     * @param datastoreLogbookOwner The owner of the logbook
     * @param logbookId The ID of the logbook to read from
     * @param pageIndex The index of the bytes32 element to read
     * @return pageContent The UTF-8 string content of the page
     */
    function getPage(address datastoreLogbookOwner, DatastoreLogbookId logbookId, uint256 pageIndex)
        external
        view
        returns (string memory pageContent)
    {
        LogbookAscii6 storage logbook = _logbooks[datastoreLogbookOwner][logbookId];
        if (pageIndex >= logbook.data.length) return "";

        bytes32 element = logbook.data[pageIndex];
        uint256 charsInElement = (logbook.data.length == 0 || pageIndex == logbook.data.length - 1)
            ? logbook.lastElementCharCount
            : CHARS_PER_BYTES32;

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
     * @param datastoreLogbookOwner The owner of the logbook
     * @param logbookId The ID of the logbook
     * @return pageCount The number of bytes32 elements (pages) in the logbook
     */
    function getPageCount(address datastoreLogbookOwner, DatastoreLogbookId logbookId)
        external
        view
        returns (uint256 pageCount)
    {
        LogbookAscii6 storage logbook = _logbooks[datastoreLogbookOwner][logbookId];
        return logbook.data.length;
    }

    /**
     * @dev Get multiple pages from the logbook
     * @param datastoreLogbookOwner The owner of the logbook
     * @param logbookId The ID of the logbook to read from
     * @param startPageIndex The starting page index
     * @param pageCount The number of pages to retrieve
     * @return pages Array of UTF-8 string content for each page
     */
    function getPages(
        address datastoreLogbookOwner,
        DatastoreLogbookId logbookId,
        uint256 startPageIndex,
        uint256 pageCount
    ) public view returns (string[] memory pages) {
        LogbookAscii6 storage logbook = _logbooks[datastoreLogbookOwner][logbookId];
        uint256 totalPages = logbook.data.length;

        if (startPageIndex >= totalPages) {
            return new string[](0);
        }

        if (startPageIndex + pageCount > totalPages) {
            pageCount = totalPages - startPageIndex;
        }

        pages = new string[](pageCount);

        for (uint256 i = 0; i < pageCount; i++) {
            uint256 pageIndex = startPageIndex + i;
            bytes32 element = logbook.data[pageIndex];
            uint256 charsInElement =
                (pageIndex == logbook.data.length - 1) ? logbook.lastElementCharCount : CHARS_PER_BYTES32;

            bytes memory ascii6Data = new bytes(charsInElement);

            for (uint256 j = 0; j < charsInElement; j++) {
                uint256 bitPosition = j * BITS_PER_CHAR;
                uint8 charValue = uint8((uint256(element) >> (256 - bitPosition - BITS_PER_CHAR)) & CHAR_BITMASK);
                ascii6Data[j] = bytes1(charValue);
            }

            pages[i] = Ascii6Lib.ascii6ToUtf8(ascii6Data);
        }

        return pages;
    }

    /**
     * @dev Get the last N pages from the logbook
     * @param datastoreLogbookOwner The owner of the logbook
     * @param logbookId The ID of the logbook to read from
     * @param pageCount The number of pages to retrieve from the end
     * @return pages Array of UTF-8 string content for the last pages
     */
    function getLastPages(address datastoreLogbookOwner, DatastoreLogbookId logbookId, uint256 pageCount)
        external
        view
        returns (string[] memory pages)
    {
        LogbookAscii6 storage logbook = _logbooks[datastoreLogbookOwner][logbookId];
        uint256 totalPages = logbook.data.length;

        if (totalPages < pageCount) {
            pageCount = totalPages;
        }

        if (totalPages == 0) {
            return new string[](0);
        }

        uint256 startPageIndex = totalPages - pageCount;
        return getPages(datastoreLogbookOwner, logbookId, startPageIndex, pageCount);
    }
}
