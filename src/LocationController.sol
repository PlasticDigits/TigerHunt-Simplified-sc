// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;
import {IWorld} from "./world/IWorld.sol";
import {DatastoreSetWrapper} from "./datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdAddress} from "./datastore/DatastoreSetAddress.sol";
import {DatastoreSetUint256, DatastoreSetIdUint256} from "./datastore/DatastoreSetUint256.sol";
import {TileID} from "./world/IWorld.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {PlayerEntity, TargetEntity, EntityLib, EntityKey} from "./command/ICommand.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// Allows approved commands to set an Entity's location.
// Can be used to move entity between tiles, worlds, and spawn/despawn.
contract LocationController is AccessManaged {
    using EntityLib for PlayerEntity;
    using EntityLib for TargetEntity;

    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;

    bytes32 public constant ENTITY_NFT_AT_LOCATION_PARTIAL =
        keccak256("ENTITY_NFT_AT_LOCATION_PARTIAL");
    bytes32 public constant ENTITY_ID_AT_LOCATION_PARTIAL =
        keccak256("ENTITY_ID_AT_LOCATION_PARTIAL");
    struct PlayerLocation {
        IWorld world;
        TileID tile;
    }

    mapping(EntityKey key => PlayerLocation location) public playerLocations;

    constructor(
        DatastoreSetWrapper datastoreSetWrapper,
        address accessAuthority
    ) AccessManaged(accessAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
    }

    function setLocation(
        PlayerEntity calldata playerEntity,
        PlayerLocation calldata playerLocation
    ) external restricted {
        EntityKey playerKey = playerEntity.key();
        IWorld oldWorld = playerLocations[playerKey].world;
        TileID oldTile = playerLocations[playerKey].tile;
        DatastoreSetUint256 entityIdOldLocationSet = DATASTORE_SET_WRAPPER
            .DATASTORE_SET_UINT256();

        // Remove the entity ID from the old location
        entityIdOldLocationSet.remove(
            getEntityIdAtLocationSetKey(
                oldWorld,
                oldTile,
                playerEntity.playerNft
            ),
            playerEntity.playerNftId
        );

        // Only add the entity if the new world is not 0x0
        if (playerLocation.world != IWorld(address(0))) {
            // Add the entity ID to the new location,
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().add(
                getEntityIdAtLocationSetKey(
                    playerLocation.world,
                    playerLocation.tile,
                    playerEntity.playerNft
                ),
                playerEntity.playerNftId
            );
            // Add the entityNFT to the new location
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(
                getEntityNftAtLocationSetKey(
                    playerLocation.world,
                    playerLocation.tile
                ),
                address(playerEntity.playerNft)
            );
        }

        // Check if the old location has no more entity IDs for this entityNFT, if so remove the entityNFT from the old location
        if (
            entityIdOldLocationSet.length(
                address(this),
                getEntityIdAtLocationSetKey(
                    oldWorld,
                    oldTile,
                    playerEntity.playerNft
                )
            ) == 0
        ) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(
                getEntityNftAtLocationSetKey(oldWorld, oldTile),
                address(playerEntity.playerNft)
            );
        }

        // Update the player's location
        playerLocations[playerKey] = playerLocation;
    }

    function getLocation(
        PlayerEntity calldata playerEntity
    ) external view returns (PlayerLocation memory) {
        return playerLocations[playerEntity.key()];
    }

    function isPlayerAndTargetInSameLocation(
        PlayerEntity calldata playerEntity,
        TargetEntity calldata targetEntity
    ) public view returns (bool) {
        // if world is 0x0, then the player has not spawned so is not at same locatiion.
        EntityKey playerKey = playerEntity.key();
        EntityKey targetKey = targetEntity.key();
        if (playerLocations[playerKey].world == IWorld(address(0))) {
            return false;
        }
        return
            playerLocations[playerKey].world ==
            playerLocations[targetKey].world &&
            TileID.unwrap(playerLocations[playerKey].tile) ==
            TileID.unwrap(playerLocations[targetKey].tile);
    }

    function getEntityNftAtLocationSetKey(
        IWorld world,
        TileID tile
    ) public pure returns (DatastoreSetIdAddress) {
        return
            DatastoreSetIdAddress.wrap(
                keccak256(
                    abi.encode(ENTITY_NFT_AT_LOCATION_PARTIAL, world, tile)
                )
            );
    }

    function getEntityIdAtLocationSetKey(
        IWorld world,
        TileID tile,
        IERC721 entityNft
    ) public pure returns (DatastoreSetIdUint256) {
        return
            DatastoreSetIdUint256.wrap(
                keccak256(
                    abi.encode(
                        ENTITY_ID_AT_LOCATION_PARTIAL,
                        world,
                        tile,
                        entityNft
                    )
                )
            );
    }
}
