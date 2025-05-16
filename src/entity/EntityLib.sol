// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
// Command interface definitions and types
pragma solidity ^0.8.30;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

struct PlayerEntity {
    IERC721 playerNft;
    uint256 playerNftId;
}

struct TargetEntity {
    IERC721 targetNft;
    uint256 targetNftId;
}

type EntityKey is bytes32;

library EntityLib {
    function key(IERC721 nft, uint256 id) internal pure returns (EntityKey) {
        return EntityKey.wrap(keccak256(abi.encode(nft, id)));
    }

    function key(PlayerEntity calldata playerEntity) internal pure returns (EntityKey) {
        return key(playerEntity.playerNft, playerEntity.playerNftId);
    }

    function key(TargetEntity calldata targetEntity) internal pure returns (EntityKey) {
        return key(targetEntity.targetNft, targetEntity.targetNftId);
    }
}
