// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
// Command interface definitions and types
pragma solidity ^0.8.30;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TileID} from "../world/IWorld.sol";
import {PlayerEntity, TargetEntity} from "../entity/EntityLib.sol";

enum CommandParameterType {
    VOID,
    SWITCH,
    ADDRESS,
    SLIDER_INT,
    SLIDER_FLOAT,
    RADIO,
    CHECKBOX,
    SELECT,
    TEXTFIELD,
    TILE
}

type SwitchParameter is bool;

type SliderIntParameter is uint64;

type SliderFloatParameter is uint256;

type RadioParameter is uint8;

type SelectParameter is uint8;

type CheckboxOption is uint8;

struct CheckboxParameter {
    CheckboxOption[] options;
    bool[] isChecked;
}

struct TextfieldParameter {
    string text;
}

struct CommandRequirements {
    IERC721 playerNft;
    IERC20 costCurrency;
    uint256 costAmount;
    uint64 cooldownSeconds;
    uint64 playerLevel;
}

interface ICommand {
    function getName() external view returns (string memory);
    function getDescription() external view returns (string memory);
    function getIconIpfsCid() external view returns (string memory);

    function getRequirements() external view returns (CommandRequirements memory);

    function getParameterType() external view returns (CommandParameterType);

    function getLastExecutedTimestamp() external view returns (uint64);
}

interface ICommandVoid is ICommand {
    function execute(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity) external;

    function isValid(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (bool);
}

interface ICommandAddress is ICommand {
    function execute(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity, address parameter)
        external;

    function isValid(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity, address parameter)
        external
        view
        returns (bool);

    function getValue(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (address);
}

interface ICommandSwitch is ICommand {
    function execute(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity, SwitchParameter parameter)
        external;

    function isValid(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity, SwitchParameter parameter)
        external
        view
        returns (bool);

    function getValue(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (bool);
}

interface ICommandSliderInt is ICommand {
    function execute(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        SliderIntParameter parameter
    ) external;

    function isValid(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        SliderIntParameter parameter
    ) external view returns (bool);

    function getValue(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (SliderIntParameter);

    function getMin(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (SliderIntParameter);

    function getMax(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (SliderIntParameter);
}

interface ICommandSliderFloat is ICommand {
    function execute(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        SliderFloatParameter parameter
    ) external;

    function isValid(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        SliderFloatParameter parameter
    ) external view returns (bool);

    function getValue(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (SliderFloatParameter);

    function getDecimals(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (uint8);

    function getMin(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (SliderFloatParameter);

    function getMax(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (SliderFloatParameter);
}

interface ICommandRadio is ICommand {
    function execute(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity, RadioParameter parameter)
        external;

    function isValid(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity, RadioParameter parameter)
        external
        view
        returns (bool);

    function getOptionNames(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (string[] memory);

    function getOptions(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (RadioParameter[] memory);

    function getSelected(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (RadioParameter);
}

interface ICommandCheckbox is ICommand {
    function execute(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        CheckboxParameter calldata parameter
    ) external;

    function isValid(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        CheckboxParameter calldata parameter
    ) external view returns (bool);

    function getOptionNames(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (string[] memory);

    function getOptions(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (CheckboxOption[] memory);

    function getValue(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (CheckboxParameter[] memory);
}

interface ICommandSelect is ICommand {
    function execute(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity, SelectParameter parameter)
        external;

    function isValid(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity, SelectParameter parameter)
        external
        view
        returns (bool);

    function getOptionNames(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (string[] memory);

    function getOptions(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (SelectParameter[] memory);

    function getValue(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (SelectParameter);
}

interface ICommandTextfield is ICommand {
    function execute(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        TextfieldParameter calldata parameter
    ) external;

    function isValid(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        TextfieldParameter calldata parameter
    ) external view returns (bool);

    function getMaxLength(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (uint256);

    function getMinLength(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (uint256);

    function getValue(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (string memory);
}

interface ICommandTile is ICommand {
    function execute(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity, TileID parameter)
        external;

    function isValid(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity, TileID parameter)
        external
        view
        returns (bool);

    function getOptions(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (TileID[] memory);

    function getValue(PlayerEntity calldata playerEntity, TargetEntity calldata targetEntity)
        external
        view
        returns (TileID);
}
