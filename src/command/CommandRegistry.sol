// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdAddress} from "../datastore/DatastoreSetAddress.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ICommand} from "./ICommand.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//Lists the available commands that can be executed on a target entity.
contract CommandRegistry is AccessManaged {
    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;

    // Partial key for commands; combine with IERC721 address to get full key
    bytes32 public constant COMMAND_KEY_PARTIAL = keccak256("COMMAND_KEY_PARTIAL");

    constructor(DatastoreSetWrapper datastoreSetWrapper, address accessAuthority) AccessManaged(accessAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
    }

    function addCommand(IERC721 targetNft, ICommand command) external restricted {
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getCommandSetKey(targetNft), address(command));
    }

    function removeCommand(IERC721 targetNft, ICommand command) external restricted {
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(getCommandSetKey(targetNft), address(command));
    }

    function getCommandSetKey(IERC721 targetNft) public pure returns (DatastoreSetIdAddress) {
        return DatastoreSetIdAddress.wrap(keccak256(abi.encode(COMMAND_KEY_PARTIAL, targetNft)));
    }
}
