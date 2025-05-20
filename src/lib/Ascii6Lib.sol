// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity 0.8.30;

type Ascii6 is bytes32;

library Ascii6Lib {
    error Ascii6Lib_InvalidStringLength();
    error Ascii6Lib_InvalidCharacter();

    function maxLength() internal pure returns (uint256) {
        return 42;
    }

    function validUTF8Char(bytes1 char) internal pure returns (bool) {
        return uint8(char) >= 32 && uint8(char) <= 96;
    }

    function fromUTF8(string memory str) internal pure returns (Ascii6) {
        bytes memory data = bytes(str);
        require(data.length <= maxLength(), Ascii6Lib_InvalidStringLength());

        bytes32 result;
        for (uint256 i = 0; i < data.length; i++) {
            require(validUTF8Char(data[i]), Ascii6Lib_InvalidCharacter());
            bytes32 sixBitShifted = bytes32(uint256(uint8(data[i]) - uint8(32))) << (6 * i);
            result |= sixBitShifted;
        }
        return Ascii6.wrap(result);
    }

    function toUTF8(Ascii6 ascii6) internal pure returns (string memory) {
        bytes memory result;

        for (uint256 i = 0; i < maxLength(); i++) {
            bytes1 sixBit = bytes1((Ascii6.unwrap(ascii6) >> (6 * i)) & bytes32(uint256(0x3F)));
            result[i] = bytes1(uint8(sixBit) + 32);
        }
        return string(result);
    }
}
