// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdAddress} from "../datastore/DatastoreSetAddress.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//Lists the entity nft contracts that are in the game, both player and nonplayer.
contract EntityNftRegistry is AccessManaged {
    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;

    // Key for entity nft accounts
    bytes32 public constant ENTITY_NFT_KEY = keccak256("ENTITY_NFT_KEY");

    constructor(DatastoreSetWrapper datastoreSetWrapper, address accessAuthority) AccessManaged(accessAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
    }

    function addEntityNft(IERC721 targetNft) external restricted {
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getEntityNftKey(), address(targetNft));
    }

    function removeEntityNft(IERC721 targetNft) external restricted {
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(getEntityNftKey(), address(targetNft));
    }

    function getEntityNftKey() public pure returns (DatastoreSetIdAddress) {
        return DatastoreSetIdAddress.wrap(ENTITY_NFT_KEY);
    }
}
