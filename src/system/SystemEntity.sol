// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdEntity} from "../datastore/DatastoreSetEntity.sol";
import {DatastoreSetIdAddress} from "../datastore/DatastoreSetAddress.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {EntityLib} from "../lib/EntityLib.sol";
import {SystemEntityComponent} from "./SystemEntityComponent.sol";

/**
 * @title SystemEntity
 * @dev Manages entities in the ECS system, supporting both NFT-backed and direct ownership
 * @notice Replaces EntityNftRegistry with expanded functionality
 * @notice Uses AccessManaged to restrict state-changing operations to authorized users
 * @notice Integrates with SystemEntityComponent for component cleanup during despawn
 */
contract SystemEntity is AccessManaged {
    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;
    SystemEntityComponent public immutable SYSTEM_ENTITY_COMPONENT;

    // Registry keys
    bytes32 public constant ENTITY_REGISTRY_KEY = keccak256("ENTITY_REGISTRY");
    bytes32 public constant ENTITY_NFT_CONTRACTS_KEY = keccak256("ENTITY_NFT_CONTRACTS");

    // Entity data storage
    mapping(EntityLib.EntityId id => EntityData data) private _entities;

    // Entity-NFT mappings
    mapping(EntityLib.EntityId entityId => NFTInfo nftInfo) private _entityToNft;
    mapping(address nftContract => mapping(uint256 tokenId => EntityLib.EntityId entityId)) private _nftToEntity;

    // Nonce for generating new entity IDs
    uint48 private _nonce;

    struct EntityData {
        address owner; // Owner for non-NFT entities (zero address if NFT-backed)
        bool exists;
    }

    struct NFTInfo {
        address nftContract;
        uint256 tokenId;
    }

    // Events
    event EntityWrapped(EntityLib.EntityId indexed entityId, address indexed nftContract, uint256 indexed tokenId);
    event EntityUnwrapped(EntityLib.EntityId indexed entityId, address indexed newOwner);

    // Errors
    error SystemEntity_EntityNotFound();
    error SystemEntity_EntityAlreadyExists();
    error SystemEntity_EntityAlreadyWrapped();
    error SystemEntity_EntityNotWrapped();
    error SystemEntity_InvalidNftContract();
    error SystemEntity_NftAlreadyWrapped();
    error SystemEntity_NotOwner();
    error SystemEntity_NotNftOwner();

    constructor(
        DatastoreSetWrapper datastoreSetWrapper,
        SystemEntityComponent systemEntityComponent,
        address accessAuthority
    ) AccessManaged(accessAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
        SYSTEM_ENTITY_COMPONENT = systemEntityComponent;
        _nonce = 1; // Start from 1, reserve 0 for null/invalid
    }

    /**
     * @dev Spawns a new entity with direct ownership (non-NFT)
     * @param entityId The entity identifier (0 to auto-generate)
     * @param owner The owner of the entity
     * @return newEntityId The ID of the spawned entity
     */
    function spawn(EntityLib.EntityId entityId, address owner)
        external
        restricted
        returns (EntityLib.EntityId newEntityId)
    {
        newEntityId = entityId;

        // Generate ID if not provided
        if (EntityLib.EntityId.unwrap(entityId) == 0) {
            newEntityId = _generateEntityId();
        }

        require(!_entities[newEntityId].exists, SystemEntity_EntityAlreadyExists());

        _entities[newEntityId] = EntityData({owner: owner, exists: true});

        // Add entity to the registry set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ENTITY().add(getEntityRegistrySetId(), newEntityId);

        return newEntityId;
    }

    /**
     * @dev Despawns an entity, removing it from the system
     * @param entityId The entity identifier to despawn
     */
    function despawn(EntityLib.EntityId entityId) external restricted {
        require(_entities[entityId].exists, SystemEntity_EntityNotFound());

        // Clear all component bindings
        SYSTEM_ENTITY_COMPONENT.clearEntityComponents(entityId);

        // If entity is wrapped, unwrap it first
        if (isWrapped(entityId)) {
            _unwrapInternal(entityId, address(0)); // Pass zero address since we're despawning
        }

        // Remove entity from the registry set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ENTITY().remove(getEntityRegistrySetId(), entityId);

        // Clean up entity data
        delete _entities[entityId];
    }

    /**
     * @dev Wraps an entity into an NFT
     * @param entityId The entity to wrap
     * @param nftContract The NFT contract address
     * @param tokenId The NFT token ID
     */
    function wrap(EntityLib.EntityId entityId, address nftContract, uint256 tokenId) external restricted {
        require(_entities[entityId].exists, SystemEntity_EntityNotFound());

        require(!isWrapped(entityId), SystemEntity_EntityAlreadyWrapped());
        require(isValidNftContract(nftContract), SystemEntity_InvalidNftContract());

        // Check if NFT is already wrapped to another entity
        require(EntityLib.EntityId.unwrap(_nftToEntity[nftContract][tokenId]) == 0, SystemEntity_NftAlreadyWrapped());

        // Set up the wrapping
        _entityToNft[entityId] = NFTInfo({nftContract: nftContract, tokenId: tokenId});
        _nftToEntity[nftContract][tokenId] = entityId;

        // Clear direct ownership since entity is now NFT-backed
        _entities[entityId].owner = address(0);

        emit EntityWrapped(entityId, nftContract, tokenId);
    }

    /**
     * @dev Unwraps an entity from an NFT back to direct ownership
     * @param entityId The entity to unwrap
     * @param newOwner The new direct owner (if zero address, uses current NFT owner)
     */
    function unwrap(EntityLib.EntityId entityId, address newOwner) external restricted {
        require(_entities[entityId].exists, SystemEntity_EntityNotFound());

        require(isWrapped(entityId), SystemEntity_EntityNotWrapped());

        _unwrapInternal(entityId, newOwner);
    }

    /**
     * @dev Internal unwrap logic
     */
    function _unwrapInternal(EntityLib.EntityId entityId, address newOwner) private {
        NFTInfo memory nftInfo = _entityToNft[entityId];

        // Determine the new owner
        address finalOwner = newOwner;
        if (finalOwner == address(0)) {
            // Use current NFT owner if no specific owner provided
            IERC721 nft = IERC721(nftInfo.nftContract);
            finalOwner = nft.ownerOf(nftInfo.tokenId);
        }

        // Clear NFT mappings
        delete _entityToNft[entityId];
        // delete by setting to zero
        _nftToEntity[nftInfo.nftContract][nftInfo.tokenId] = EntityLib.EntityId.wrap(0);

        // Set direct ownership
        _entities[entityId].owner = finalOwner;

        emit EntityUnwrapped(entityId, finalOwner);
    }

    /**
     * @dev Adds an NFT contract to the registry of valid entity NFT contracts
     * @param nftContract The NFT contract to add
     */
    function addEntityNftContract(address nftContract) external restricted {
        require(nftContract != address(0), SystemEntity_InvalidNftContract());

        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getEntityNftContractsSetId(), nftContract);
    }

    /**
     * @dev Removes an NFT contract from the registry
     * @param nftContract The NFT contract to remove
     */
    function removeEntityNftContract(address nftContract) external restricted {
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(getEntityNftContractsSetId(), nftContract);
    }

    /**
     * @dev Generates a new unique entity ID using nonce
     * @return entityId The generated entity ID
     */
    function _generateEntityId() private returns (EntityLib.EntityId entityId) {
        do {
            entityId = EntityLib.EntityId.wrap(_nonce);
            _nonce++;
        } while (_entities[entityId].exists);

        return entityId;
    }

    // View functions

    /**
     * @dev Returns the entity registry set identifier
     */
    function getEntityRegistrySetId() public pure returns (DatastoreSetIdEntity) {
        return DatastoreSetIdEntity.wrap(ENTITY_REGISTRY_KEY);
    }

    /**
     * @dev Returns the entity NFT contracts set identifier
     */
    function getEntityNftContractsSetId() public pure returns (DatastoreSetIdAddress) {
        return DatastoreSetIdAddress.wrap(ENTITY_NFT_CONTRACTS_KEY);
    }

    /**
     * @dev Checks if an entity exists
     * @param entityId The entity identifier to check
     * @return True if the entity exists
     */
    function exists(EntityLib.EntityId entityId) external view returns (bool) {
        return _entities[entityId].exists;
    }

    /**
     * @dev Checks if an entity is wrapped in an NFT
     * @param entityId The entity identifier to check
     * @return True if the entity is wrapped
     */
    function isWrapped(EntityLib.EntityId entityId) public view returns (bool) {
        return _entityToNft[entityId].nftContract != address(0);
    }

    /**
     * @dev Checks if an NFT contract is registered as valid for entities
     * @param nftContract The NFT contract to check
     * @return True if the contract is valid
     */
    function isValidNftContract(address nftContract) public view returns (bool) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().contains(
            address(this), getEntityNftContractsSetId(), nftContract
        );
    }

    /**
     * @dev Returns the owner of an entity
     * @param entityId The entity identifier
     * @return owner The owner address (NFT owner if wrapped, direct owner otherwise)
     */
    function getOwner(EntityLib.EntityId entityId) external view returns (address owner) {
        require(_entities[entityId].exists, SystemEntity_EntityNotFound());

        if (isWrapped(entityId)) {
            NFTInfo memory nftInfo = _entityToNft[entityId];
            IERC721 nft = IERC721(nftInfo.nftContract);
            return nft.ownerOf(nftInfo.tokenId);
        } else {
            return _entities[entityId].owner;
        }
    }

    /**
     * @dev Returns NFT information for a wrapped entity
     * @param entityId The entity identifier
     * @return nftContract The NFT contract address
     * @return tokenId The NFT token ID
     */
    function getNftInfo(EntityLib.EntityId entityId) external view returns (address nftContract, uint256 tokenId) {
        require(isWrapped(entityId), SystemEntity_EntityNotWrapped());

        NFTInfo memory info = _entityToNft[entityId];
        return (info.nftContract, info.tokenId);
    }

    /**
     * @dev Returns the entity ID for a given NFT
     * @param nftContract The NFT contract address
     * @param tokenId The NFT token ID
     * @return entityId The entity ID (zero if not wrapped)
     */
    function getEntityByNft(address nftContract, uint256 tokenId) external view returns (EntityLib.EntityId entityId) {
        return _nftToEntity[nftContract][tokenId];
    }

    /**
     * @dev Returns all registered entity IDs
     * @return entityIds Array of all entity identifiers
     */
    function getAllEntities() external view returns (EntityLib.EntityId[] memory entityIds) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_ENTITY().getAll(address(this), getEntityRegistrySetId());
    }

    /**
     * @dev Returns all registered NFT contracts
     * @return nftContracts Array of all NFT contract addresses
     */
    function getAllNftContracts() external view returns (address[] memory nftContracts) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().getAll(address(this), getEntityNftContractsSetId());
    }

    /**
     * @dev Returns the total number of entities
     * @return count The number of entities
     */
    function getEntityCount() external view returns (uint256 count) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_ENTITY().length(address(this), getEntityRegistrySetId());
    }

    /**
     * @dev Returns the current nonce value
     * @return nonce The current nonce
     */
    function getNonce() external view returns (uint48 nonce) {
        return _nonce;
    }
}
