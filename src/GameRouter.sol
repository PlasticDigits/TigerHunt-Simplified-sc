// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
// Entrypoint for playing the game, executes commands
pragma solidity ^0.8.30;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DatastoreSetWrapper} from "./datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdAddress} from "./datastore/DatastoreSetAddress.sol";
import {DatastoreSetIdBytes32} from "./datastore/DatastoreSetBytes32.sol";
import {CommandRegistry} from "./CommandRegistry.sol";
import {ICommand, ICommandVoid, ICommandSelect, ICommandCheckbox, SelectParameter, CheckboxParameter, ICommandAddress, ICommandSwitch, SwitchParameter, ICommandSliderInt, SliderIntParameter, ICommandSliderFloat, SliderFloatParameter, ICommandRadio, RadioParameter, ICommandCheckbox, CheckboxParameter, ICommandTextfield, TextfieldParameter, ICommandTile, TilePackedXYZ, PlayerEntity, TargetEntity, CommandKey, CommandRequirements, CommandParameterType} from "./ICommand.sol";

contract GameRouter {
    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;
    CommandRegistry public immutable COMMAND_REGISTRY;
    error CommandNotFound(ICommand command);
    error NotPlayerOrOperator(address account);
    error NotOwner(address account);
    error CommandOnCooldown(uint64 availableAt);
    error InvalidCommandParameterType();
    error InvalidCommandCall();
    constructor(
        DatastoreSetWrapper datastoreSetWrapper,
        CommandRegistry commandRegistry
    ) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
        COMMAND_REGISTRY = commandRegistry;
    }

    modifier onlyPlayerOrOperator(PlayerEntity calldata playerEntity) {
        address player = playerEntity.playerNft.ownerOf(
            playerEntity.playerNftId
        );
        if (
            msg.sender != player &&
            !DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().contains(
                address(this),
                DatastoreSetIdAddress.wrap(keccak256(abi.encode(player))),
                msg.sender
            )
        ) {
            revert NotPlayerOrOperator(msg.sender);
        }
        _;
    }

    function executeCommandVoid(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        ICommandVoid command
    ) external {
        _checkGenericCommandRequirements(playerEntity, targetEntity, command);
        if (command.getParameterType() != CommandParameterType.VOID) {
            revert InvalidCommandParameterType();
        }
        if (!command.isValid(playerEntity, targetEntity)) {
            revert InvalidCommandCall();
        }
        command.execute(playerEntity, targetEntity);
    }

    function executeCommandAddress(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        ICommandAddress command,
        address parameter
    ) external {
        _checkGenericCommandRequirements(playerEntity, targetEntity, command);
        if (command.getParameterType() != CommandParameterType.ADDRESS) {
            revert InvalidCommandParameterType();
        }
        if (!command.isValid(playerEntity, targetEntity, parameter)) {
            revert InvalidCommandCall();
        }
        command.execute(playerEntity, targetEntity, parameter);
    }

    function executeCommandSwitch(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        ICommandSwitch command,
        SwitchParameter parameter
    ) external {
        _checkGenericCommandRequirements(playerEntity, targetEntity, command);
        if (command.getParameterType() != CommandParameterType.SWITCH) {
            revert InvalidCommandParameterType();
        }
        if (!command.isValid(playerEntity, targetEntity, parameter)) {
            revert InvalidCommandCall();
        }
        command.execute(playerEntity, targetEntity, parameter);
    }

    function executeCommandSliderInt(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        ICommandSliderInt command,
        SliderIntParameter parameter
    ) external {
        _checkGenericCommandRequirements(playerEntity, targetEntity, command);
        if (command.getParameterType() != CommandParameterType.SLIDER_INT) {
            revert InvalidCommandParameterType();
        }
        if (!command.isValid(playerEntity, targetEntity, parameter)) {
            revert InvalidCommandCall();
        }
        command.execute(playerEntity, targetEntity, parameter);
    }

    function executeCommandSliderFloat(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        ICommandSliderFloat command,
        SliderFloatParameter parameter
    ) external {
        _checkGenericCommandRequirements(playerEntity, targetEntity, command);
        if (command.getParameterType() != CommandParameterType.SLIDER_FLOAT) {
            revert InvalidCommandParameterType();
        }
        if (!command.isValid(playerEntity, targetEntity, parameter)) {
            revert InvalidCommandCall();
        }
        command.execute(playerEntity, targetEntity, parameter);
    }

    function executeCommandRadio(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        ICommandRadio command,
        RadioParameter parameter
    ) external {
        _checkGenericCommandRequirements(playerEntity, targetEntity, command);
        if (command.getParameterType() != CommandParameterType.RADIO) {
            revert InvalidCommandParameterType();
        }
        if (!command.isValid(playerEntity, targetEntity, parameter)) {
            revert InvalidCommandCall();
        }
        command.execute(playerEntity, targetEntity, parameter);
    }

    function executeCommandCheckbox(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        ICommandCheckbox command,
        CheckboxParameter calldata parameter
    ) external {
        _checkGenericCommandRequirements(playerEntity, targetEntity, command);
        if (command.getParameterType() != CommandParameterType.CHECKBOX) {
            revert InvalidCommandParameterType();
        }
        if (!command.isValid(playerEntity, targetEntity, parameter)) {
            revert InvalidCommandCall();
        }
        command.execute(playerEntity, targetEntity, parameter);
    }

    function executeCommandSelect(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        ICommandSelect command,
        SelectParameter parameter
    ) external {
        _checkGenericCommandRequirements(playerEntity, targetEntity, command);
        if (command.getParameterType() != CommandParameterType.SELECT) {
            revert InvalidCommandParameterType();
        }
        if (!command.isValid(playerEntity, targetEntity, parameter)) {
            revert InvalidCommandCall();
        }
        command.execute(playerEntity, targetEntity, parameter);
    }

    function executeCommandTextfield(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        ICommandTextfield command,
        TextfieldParameter calldata parameter
    ) external {
        _checkGenericCommandRequirements(playerEntity, targetEntity, command);
        if (command.getParameterType() != CommandParameterType.TEXTFIELD) {
            revert InvalidCommandParameterType();
        }
        if (!command.isValid(playerEntity, targetEntity, parameter)) {
            revert InvalidCommandCall();
        }
        command.execute(playerEntity, targetEntity, parameter);
    }

    function executeCommandTile(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        ICommandTile command,
        TilePackedXYZ calldata parameter
    ) external {
        _checkGenericCommandRequirements(playerEntity, targetEntity, command);
        if (command.getParameterType() != CommandParameterType.TILE) {
            revert InvalidCommandParameterType();
        }
        if (!command.isValid(playerEntity, targetEntity, parameter)) {
            revert InvalidCommandCall();
        }
        command.execute(playerEntity, targetEntity, parameter);
    }

    function _checkGenericCommandRequirements(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity,
        ICommand command
    ) internal onlyPlayerOrOperator(playerEntity) {
        // Check if the command is registered
        if (
            !DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().contains(
                address(COMMAND_REGISTRY),
                COMMAND_REGISTRY.getCommandSetKey(targetEntity),
                address(command)
            )
        ) {
            revert CommandNotFound(command);
        }
        CommandRequirements memory requirements = command.getRequirements();

        // Send payment if needed
        if (requirements.costCurrency != IERC20(address(0))) {
            requirements.costCurrency.transferFrom(
                msg.sender,
                address(command),
                requirements.costAmount
            );
        }
        // If the command is on cooldown, revert
        if (
            command.getLastExecutedTimestamp() + requirements.cooldownSeconds >
            block.timestamp
        ) {
            revert CommandOnCooldown(
                command.getLastExecutedTimestamp() +
                    requirements.cooldownSeconds
            );
        }
    }

    function addOperator(address operator) external {
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(
            getOperatorSetKey(msg.sender),
            operator
        );
    }

    function removeOperator(address operator) external {
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(
            getOperatorSetKey(msg.sender),
            operator
        );
    }

    function getOperatorSetKey(
        address player
    ) public pure returns (DatastoreSetIdAddress) {
        return DatastoreSetIdAddress.wrap(keccak256(abi.encode(player)));
    }
}
