// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity 0.8.30;

type EffectTimestamp is uint64;

type EffectIndex is uint256;

interface IEffect {
    // Get a human-readable name for the effect
    function getName() external view returns (string memory);

    // Get a description of the effect for display purposes
    function getDescription(EffectIndex index) external view returns (string memory);

    // Get the timestamp of the effect
    function getTimestamp(EffectIndex index) external view returns (EffectTimestamp);

    // Accept the effect
    function accept(EffectIndex index) external;
}
