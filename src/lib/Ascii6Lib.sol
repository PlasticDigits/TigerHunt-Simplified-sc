// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

/**
 * @title Ascii6Lib
 * @dev Library for converting UTF-8 strings to ASCII6 encoding and managing LogbookAscii6 data
 * ASCII6 uses 6 bits per character (64 possible values):
 * - Index 0: Space
 * - Index 1-26: A-Z
 * - Index 27-36: 0-9
 * - Index 37-62: Jungle/Tiger themed emojis
 * - Index 63: Newline (\n)
 */
library Ascii6Lib {
    type Ascii6Index is uint8;

    /**
     * @dev Convert a single UTF-8 character to ASCII6 index
     * @param char The UTF-8 character bytes
     * @return index The ASCII6 index (0-63)
     */
    function charToAscii6(bytes memory char) internal pure returns (Ascii6Index index) {
        if (char.length == 1) {
            return _singleByteToAscii6(char[0]);
        }
        return _multiByteToAscii6(char);
    }

    /**
     * @dev Convert single byte character to ASCII6 index
     */
    function _singleByteToAscii6(bytes1 b) private pure returns (Ascii6Index) {
        if (b == 0x20) return Ascii6Index.wrap(0); // Space
        if (b >= 0x41 && b <= 0x5A) return Ascii6Index.wrap(uint8(b) - 0x40); // A-Z
        if (b >= 0x30 && b <= 0x39) return Ascii6Index.wrap(uint8(b) - 0x30 + 27); // 0-9
        return Ascii6Index.wrap(0); // Default to space
    }

    /**
     * @dev Convert multi-byte UTF-8 character to ASCII6 index
     */
    function _multiByteToAscii6(bytes memory char) private pure returns (Ascii6Index) {
        bytes4 charBytes4 = _bytesToBytes4(char);
        if (charBytes4 == bytes4("\n")) return Ascii6Index.wrap(63);
        return _emojiToAscii6Part1(charBytes4);
    }

    /**
     * @dev Convert bytes to bytes4
     */
    function _bytesToBytes4(bytes memory char) private pure returns (bytes4 result) {
        for (uint256 i = 0; i < char.length && i < 4; i++) {
            result |= bytes4(char[i]) >> (i * 8);
        }
    }

    /**
     * @dev Convert emoji bytes4 to ASCII6 index (part 1)
     */
    // solhint-disable-next-line code-complexity
    function _emojiToAscii6Part1(bytes4 charBytes4) private pure returns (Ascii6Index) {
        if (charBytes4 == bytes4(unicode"🐅")) return Ascii6Index.wrap(37); // Tiger - The apex predator
        if (charBytes4 == bytes4(unicode"👑")) return Ascii6Index.wrap(38); // Crown - Empire leadership
        if (charBytes4 == bytes4(unicode"🏰")) return Ascii6Index.wrap(39); // Castle - Empire stronghold
        if (charBytes4 == bytes4(unicode"⚔")) return Ascii6Index.wrap(40); // Crossed swords - Battle
        if (charBytes4 == bytes4(unicode"🏹")) return Ascii6Index.wrap(41); // Bow - Hunting prowess
        if (charBytes4 == bytes4(unicode"🌙")) return Ascii6Index.wrap(42); // Moon - Night hunting
        if (charBytes4 == bytes4(unicode"🔥")) return Ascii6Index.wrap(43); // Fire - Tiger's fury
        if (charBytes4 == bytes4(unicode"💎")) return Ascii6Index.wrap(44); // Diamond - Rare treasures
        if (charBytes4 == bytes4(unicode"🏆")) return Ascii6Index.wrap(45); // Trophy - Victory spoils
        if (charBytes4 == bytes4(unicode"⭐")) return Ascii6Index.wrap(46); // Star - Experience/Fame
        if (charBytes4 == bytes4(unicode"🗡")) return Ascii6Index.wrap(47); // Dagger - Stealth attacks
        if (charBytes4 == bytes4(unicode"🛡")) return Ascii6Index.wrap(48); // Shield - Defense
        if (charBytes4 == bytes4(unicode"🌿")) return Ascii6Index.wrap(49); // Herb - Jungle camouflage
        if (charBytes4 == bytes4(unicode"🌳")) return Ascii6Index.wrap(50); // Tree - Territory markers
        if (charBytes4 == bytes4(unicode"🦌")) return Ascii6Index.wrap(51); // Deer - Prime hunting target
        if (charBytes4 == bytes4(unicode"🐗")) return Ascii6Index.wrap(52); // Boar - Dangerous prey
        if (charBytes4 == bytes4(unicode"🐍")) return Ascii6Index.wrap(53); // Snake - Jungle threats
        if (charBytes4 == bytes4(unicode"🦅")) return Ascii6Index.wrap(54); // Eagle - Sky scouts
        if (charBytes4 == bytes4(unicode"🌋")) return Ascii6Index.wrap(55); // Volcano - Karynx landscape
        if (charBytes4 == bytes4(unicode"⚡")) return Ascii6Index.wrap(56); // Lightning - Tiger speed
        if (charBytes4 == bytes4(unicode"🔮")) return Ascii6Index.wrap(57); // Crystal ball - Ancient magic
        if (charBytes4 == bytes4(unicode"🏛")) return Ascii6Index.wrap(58); // Temple - Empire monuments
        if (charBytes4 == bytes4(unicode"🗿")) return Ascii6Index.wrap(59); // Moai - Ancient ruins
        if (charBytes4 == bytes4(unicode"🌟")) return Ascii6Index.wrap(60); // Glowing star - Legendary status
        if (charBytes4 == bytes4(unicode"💀")) return Ascii6Index.wrap(61); // Skull - Fallen enemies
        if (charBytes4 == bytes4(unicode"🎯")) return Ascii6Index.wrap(62); // Target - Perfect hunt
        return Ascii6Index.wrap(0); // Default to space
    }

    /**
     * @dev Convert ASCII6 index to UTF-8 character
     * @param index The ASCII6 index (0-63)
     * @return char The UTF-8 character as string
     */
    function ascii6ToChar(Ascii6Index index) internal pure returns (string memory char) {
        uint8 i = Ascii6Index.unwrap(index);
        if (i == 0) return " ";
        if (i >= 1 && i <= 26) return _indexToAlpha(index);
        if (i >= 27 && i <= 36) return _indexToDigit(index);
        if (i == 63) return "\n";
        return _indexToEmoji(index);
    }

    /**
     * @dev Convert index to alphabetic character
     */
    function _indexToAlpha(Ascii6Index index) private pure returns (string memory) {
        bytes memory result = new bytes(1);
        result[0] = bytes1(uint8(Ascii6Index.unwrap(index) + 0x40));
        return string(result);
    }

    /**
     * @dev Convert index to digit character
     */
    function _indexToDigit(Ascii6Index index) private pure returns (string memory) {
        bytes memory result = new bytes(1);
        result[0] = bytes1(uint8(Ascii6Index.unwrap(index) - 27 + 0x30));
        return string(result);
    }

    /**
     * @dev Convert index to emoji character
     */
    // solhint-disable-next-line code-complexity
    function _indexToEmoji(Ascii6Index index) private pure returns (string memory) {
        uint8 i = Ascii6Index.unwrap(index);
        if (i == 37) return unicode"🐅"; // Tiger - The apex predator
        if (i == 38) return unicode"👑"; // Crown - Empire leadership
        if (i == 39) return unicode"🏰"; // Castle - Empire stronghold
        if (i == 40) return unicode"⚔"; // Crossed swords - Battle
        if (i == 41) return unicode"🏹"; // Bow - Hunting prowess
        if (i == 42) return unicode"🌙"; // Moon - Night hunting
        if (i == 43) return unicode"🔥"; // Fire - Tiger's fury
        if (i == 44) return unicode"💎"; // Diamond - Rare treasures
        if (i == 45) return unicode"🏆"; // Trophy - Victory spoils
        if (i == 46) return unicode"⭐"; // Star - Experience/Fame
        if (i == 47) return unicode"🗡"; // Dagger - Stealth attacks
        if (i == 48) return unicode"🛡"; // Shield - Defense
        if (i == 49) return unicode"🌿"; // Herb - Jungle camouflage
        if (i == 50) return unicode"🌳"; // Tree - Territory markers
        if (i == 51) return unicode"🦌"; // Deer - Prime hunting target
        if (i == 52) return unicode"🐗"; // Boar - Dangerous prey
        if (i == 53) return unicode"🐍"; // Snake - Jungle threats
        if (i == 54) return unicode"🦅"; // Eagle - Sky scouts
        if (i == 55) return unicode"🌋"; // Volcano - Karynx landscape
        if (i == 56) return unicode"⚡"; // Lightning - Tiger speed
        if (i == 57) return unicode"🔮"; // Crystal ball - Ancient magic
        if (i == 58) return unicode"🏛"; // Temple - Empire monuments
        if (i == 59) return unicode"🗿"; // Moai - Ancient ruins
        if (i == 60) return unicode"🌟"; // Glowing star - Legendary status
        if (i == 61) return unicode"💀"; // Skull - Fallen enemies
        if (i == 62) return unicode"🎯"; // Target - Perfect hunt
        return " "; // Default to space
    }

    /**
     * @dev Convert UTF-8 string to ASCII6 encoded bytes
     * @param utf8String The input UTF-8 string
     * @return ascii6Data The ASCII6 encoded data
     */
    function utf8ToAscii6(string memory utf8String) internal pure returns (bytes memory ascii6Data) {
        bytes memory inputBytes = bytes(utf8String);
        bytes memory tempOutput = new bytes(inputBytes.length);
        uint256 outputIndex = 0;
        uint256 i = 0;

        while (i < inputBytes.length) {
            (bytes memory char, uint256 charLength) = _extractUtf8Char(inputBytes, i);
            Ascii6Index ascii6Index = charToAscii6(char);
            tempOutput[outputIndex] = bytes1(Ascii6Index.unwrap(ascii6Index));
            outputIndex++;
            i += charLength;
        }

        ascii6Data = new bytes(outputIndex);
        for (uint256 j = 0; j < outputIndex; j++) {
            ascii6Data[j] = tempOutput[j];
        }
    }

    /**
     * @dev Extract UTF-8 character from bytes array
     */
    function _extractUtf8Char(bytes memory inputBytes, uint256 index)
        private
        pure
        returns (bytes memory char, uint256 charLength)
    {
        charLength = _getUtf8CharLength(inputBytes[index]);
        char = new bytes(charLength);

        for (uint256 j = 0; j < charLength && index + j < inputBytes.length; j++) {
            char[j] = inputBytes[index + j];
        }
    }

    /**
     * @dev Get UTF-8 character length from first byte
     */
    function _getUtf8CharLength(bytes1 firstByte) private pure returns (uint256) {
        if (firstByte & 0x80 == 0) return 1;
        if (firstByte & 0xE0 == 0xC0) return 2;
        if (firstByte & 0xF0 == 0xE0) return 3;
        if (firstByte & 0xF8 == 0xF0) return 4;
        return 1; // Default
    }

    /**
     * @dev Convert ASCII6 encoded bytes to UTF-8 string
     * @param ascii6Data The ASCII6 encoded data
     * @return utf8String The decoded UTF-8 string
     */
    function ascii6ToUtf8(bytes memory ascii6Data) internal pure returns (string memory utf8String) {
        bytes memory result = new bytes(ascii6Data.length * 4);
        uint256 resultIndex = 0;

        for (uint256 i = 0; i < ascii6Data.length; i++) {
            uint8 index = uint8(ascii6Data[i]);
            string memory char = ascii6ToChar(Ascii6Index.wrap(index));
            bytes memory charBytes = bytes(char);

            for (uint256 j = 0; j < charBytes.length; j++) {
                result[resultIndex] = charBytes[j];
                resultIndex++;
            }
        }

        bytes memory finalResult = new bytes(resultIndex);
        for (uint256 i = 0; i < resultIndex; i++) {
            finalResult[i] = result[i];
        }

        utf8String = string(finalResult);
    }
}
