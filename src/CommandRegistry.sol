// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {DatastoreSetWrapper} from "./datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdAddress} from "./datastore/DatastoreSetAddress.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {ICommand, CommandKey, TargetEntity} from "./ICommand.sol";

//Lists the available commands that can be executed on a target entity.
contract CommandRegistry is AccessManaged {
    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;

    constructor(
        DatastoreSetWrapper datastoreSetWrapper,
        address accessAuthority
    ) AccessManaged(accessAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
    }

    function addCommand(
        TargetEntity calldata targetEntity,
        ICommand command
    ) external {
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(
            getCommandSetKey(targetEntity),
            address(command)
        );
    }

    function removeCommand(
        TargetEntity calldata targetEntity,
        ICommand command
    ) external {
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(
            getCommandSetKey(targetEntity),
            address(command)
        );
    }

    function getCommandSetKey(
        TargetEntity calldata targetEntity
    ) public pure returns (DatastoreSetIdAddress) {
        return DatastoreSetIdAddress.wrap(keccak256(abi.encode(targetEntity)));
    }
}
