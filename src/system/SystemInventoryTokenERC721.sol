// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.30;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdAddress} from "../datastore/DatastoreSetAddress.sol";
import {DatastoreSetIdUint256} from "../datastore/DatastoreSetUint256.sol";

/**
 * @title SystemInventoryTokenERC721
 * @dev System for managing ERC721 token inventories in the ECS architecture
 * @notice Handles deposit, withdraw, transfer, and burn operations for ERC721 tokens
 * @notice Operates on InventoryTokenERC721Id rather than EntityId for maximum composability
 * @notice Inventory IDs can be linked to entities via components, shared between entities, or exist independently
 */
contract SystemInventoryTokenERC721 is AccessManaged {
    // Custom type for inventory identification
    type InventoryTokenERC721Id is uint48;

    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;

    // Registry keys for ERC721 tokens stored by inventories
    bytes32 public constant INVENTORY_ERC721_CONTRACTS_KEY = keccak256("INVENTORY_ERC721_CONTRACTS");
    bytes32 public constant INVENTORY_ERC721_TOKEN_IDS_KEY = keccak256("INVENTORY_ERC721_TOKEN_IDS");

    // Inventory metadata
    mapping(InventoryTokenERC721Id inventoryId => InventoryMetadata metadata) public inventoryMetadata;

    // Nonce for generating new inventory IDs
    uint48 private _nonce;

    struct InventoryMetadata {
        bool exists;
        string name; // Optional human-readable name
        address creator; // Who created this inventory
        uint256 createdAt; // Block timestamp of creation
    }

    // Events
    event InventoryCreated(InventoryTokenERC721Id indexed inventoryId, address indexed creator, string name);
    event InventoryDestroyed(InventoryTokenERC721Id indexed inventoryId);
    event ERC721Deposited(InventoryTokenERC721Id indexed inventoryId, IERC721 indexed nft, uint256[] tokenIds);
    event ERC721Withdrawn(InventoryTokenERC721Id indexed inventoryId, IERC721 indexed nft, uint256[] tokenIds);
    event ERC721Transferred(
        InventoryTokenERC721Id indexed fromInventoryId,
        InventoryTokenERC721Id indexed toInventoryId,
        IERC721 indexed nft,
        uint256[] tokenIds
    );
    event ERC721Burned(InventoryTokenERC721Id indexed inventoryId, ERC721Burnable indexed nft, uint256[] tokenIds);

    // Errors
    error SystemInventoryTokenERC721_InventoryNotFound();
    error SystemInventoryTokenERC721_InventoryAlreadyExists();
    error SystemInventoryTokenERC721_TokenNotOwned();
    error SystemInventoryTokenERC721_TransferFailed();
    error SystemInventoryTokenERC721_DepositFailed();
    error SystemInventoryTokenERC721_WithdrawFailed();
    error SystemInventoryTokenERC721_BurnFailed();
    error SystemInventoryTokenERC721_InventoryNotEmpty();
    error SystemInventoryTokenERC721_EmptyTokenArray();

    constructor(DatastoreSetWrapper datastoreSetWrapper, address accessAuthority) AccessManaged(accessAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
        _nonce = 1; // Start from 1, reserve 0 for null/invalid
    }

    /**
     * @dev Creates a new inventory
     * @param inventoryId The inventory identifier (0 to auto-generate)
     * @param name Optional human-readable name for the inventory
     * @return newInventoryId The ID of the created inventory
     */
    function createInventory(InventoryTokenERC721Id inventoryId, string calldata name)
        external
        restricted
        returns (InventoryTokenERC721Id newInventoryId)
    {
        newInventoryId = inventoryId;

        // Generate ID if not provided
        if (InventoryTokenERC721Id.unwrap(inventoryId) == 0) {
            newInventoryId = _generateInventoryId();
        }

        if (inventoryMetadata[newInventoryId].exists) {
            revert SystemInventoryTokenERC721_InventoryAlreadyExists();
        }

        inventoryMetadata[newInventoryId] =
            InventoryMetadata({exists: true, name: name, creator: _msgSender(), createdAt: block.timestamp});

        emit InventoryCreated(newInventoryId, _msgSender(), name);
        return newInventoryId;
    }

    /**
     * @dev Destroys an inventory (must be empty)
     * @param inventoryId The inventory identifier to destroy
     */
    function destroyInventory(InventoryTokenERC721Id inventoryId) external restricted {
        if (!inventoryMetadata[inventoryId].exists) {
            revert SystemInventoryTokenERC721_InventoryNotFound();
        }

        // Check that inventory is empty
        address[] memory nftContracts = getInventoryNftContracts(inventoryId);
        if (nftContracts.length > 0) {
            revert SystemInventoryTokenERC721_InventoryNotEmpty();
        }

        delete inventoryMetadata[inventoryId];
        emit InventoryDestroyed(inventoryId);
    }

    /**
     * @dev Deposits ERC721 tokens into an inventory
     * @param depositor Address providing the tokens
     * @param inventoryId The inventory receiving the tokens
     * @param nft The ERC721 contract
     * @param tokenIds Array of token IDs to deposit
     */
    function deposit(address depositor, InventoryTokenERC721Id inventoryId, IERC721 nft, uint256[] calldata tokenIds)
        external
        restricted
    {
        if (!inventoryMetadata[inventoryId].exists) {
            revert SystemInventoryTokenERC721_InventoryNotFound();
        }
        if (tokenIds.length == 0) {
            revert SystemInventoryTokenERC721_EmptyTokenArray();
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            try nft.transferFrom(depositor, address(this), tokenIds[i]) {
                DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().add(
                    getInventoryERC721TokenIdSetKey(inventoryId, nft), tokenIds[i]
                );
            } catch {
                revert SystemInventoryTokenERC721_DepositFailed();
            }
        }

        // Add NFT contract to inventory's contract set if this is the first deposit
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getInventoryERC721ContractSetKey(inventoryId), address(nft));

        emit ERC721Deposited(inventoryId, nft, tokenIds);
    }

    /**
     * @dev Withdraws ERC721 tokens from an inventory
     * @param receiver Address to receive the tokens
     * @param inventoryId The inventory providing the tokens
     * @param nft The ERC721 contract
     * @param tokenIds Array of token IDs to withdraw
     */
    function withdraw(address receiver, InventoryTokenERC721Id inventoryId, IERC721 nft, uint256[] calldata tokenIds)
        external
        restricted
    {
        if (!inventoryMetadata[inventoryId].exists) {
            revert SystemInventoryTokenERC721_InventoryNotFound();
        }
        if (tokenIds.length == 0) {
            revert SystemInventoryTokenERC721_EmptyTokenArray();
        }

        DatastoreSetIdUint256 tokenIdSetKey = getInventoryERC721TokenIdSetKey(inventoryId, nft);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().contains(address(this), tokenIdSetKey, tokenIds[i])) {
                revert SystemInventoryTokenERC721_TokenNotOwned();
            }

            try nft.transferFrom(address(this), receiver, tokenIds[i]) {
                DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().remove(tokenIdSetKey, tokenIds[i]);
            } catch {
                revert SystemInventoryTokenERC721_WithdrawFailed();
            }
        }

        // Remove NFT contract from inventory if no tokens remain
        _removeNftFromInventoryIfEmpty(inventoryId, nft);

        emit ERC721Withdrawn(inventoryId, nft, tokenIds);
    }

    /**
     * @dev Transfers ERC721 tokens between inventories
     * @param fromInventoryId The inventory providing the tokens
     * @param toInventoryId The inventory receiving the tokens
     * @param nft The ERC721 contract
     * @param tokenIds Array of token IDs to transfer
     */
    function transfer(
        InventoryTokenERC721Id fromInventoryId,
        InventoryTokenERC721Id toInventoryId,
        IERC721 nft,
        uint256[] calldata tokenIds
    ) external restricted {
        if (!inventoryMetadata[fromInventoryId].exists) {
            revert SystemInventoryTokenERC721_InventoryNotFound();
        }
        if (!inventoryMetadata[toInventoryId].exists) {
            revert SystemInventoryTokenERC721_InventoryNotFound();
        }
        if (tokenIds.length == 0) {
            revert SystemInventoryTokenERC721_EmptyTokenArray();
        }

        DatastoreSetIdUint256 fromTokenIdSetKey = getInventoryERC721TokenIdSetKey(fromInventoryId, nft);
        DatastoreSetIdUint256 toTokenIdSetKey = getInventoryERC721TokenIdSetKey(toInventoryId, nft);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().contains(address(this), fromTokenIdSetKey, tokenIds[i]))
            {
                revert SystemInventoryTokenERC721_TokenNotOwned();
            }

            // Remove from source inventory
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().remove(fromTokenIdSetKey, tokenIds[i]);

            // Add to destination inventory
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().add(toTokenIdSetKey, tokenIds[i]);
        }

        // Update contract sets
        _removeNftFromInventoryIfEmpty(fromInventoryId, nft);
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getInventoryERC721ContractSetKey(toInventoryId), address(nft));

        emit ERC721Transferred(fromInventoryId, toInventoryId, nft, tokenIds);
    }

    /**
     * @dev Burns ERC721 tokens from an inventory
     * @param inventoryId The inventory providing the tokens to burn
     * @param nft The burnable ERC721 contract
     * @param tokenIds Array of token IDs to burn
     */
    function burn(InventoryTokenERC721Id inventoryId, ERC721Burnable nft, uint256[] calldata tokenIds)
        external
        restricted
    {
        if (!inventoryMetadata[inventoryId].exists) {
            revert SystemInventoryTokenERC721_InventoryNotFound();
        }
        if (tokenIds.length == 0) {
            revert SystemInventoryTokenERC721_EmptyTokenArray();
        }

        DatastoreSetIdUint256 tokenIdSetKey = getInventoryERC721TokenIdSetKey(inventoryId, nft);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().contains(address(this), tokenIdSetKey, tokenIds[i])) {
                revert SystemInventoryTokenERC721_TokenNotOwned();
            }

            try nft.burn(tokenIds[i]) {
                DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().remove(tokenIdSetKey, tokenIds[i]);
            } catch {
                revert SystemInventoryTokenERC721_BurnFailed();
            }
        }

        // Remove NFT contract from inventory if no tokens remain
        _removeNftFromInventoryIfEmpty(inventoryId, nft);

        emit ERC721Burned(inventoryId, nft, tokenIds);
    }

    /**
     * @dev Internal function to remove NFT contract from inventory if no tokens remain
     * @param inventoryId The inventory ID
     * @param nft The ERC721 contract
     */
    function _removeNftFromInventoryIfEmpty(InventoryTokenERC721Id inventoryId, IERC721 nft) internal {
        DatastoreSetIdUint256 tokenIdSetKey = getInventoryERC721TokenIdSetKey(inventoryId, nft);
        if (DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().length(address(this), tokenIdSetKey) == 0) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(
                getInventoryERC721ContractSetKey(inventoryId), address(nft)
            );
        }
    }

    /**
     * @dev Gets the datastore set key for an inventory's ERC721 contracts
     * @param inventoryId The inventory ID
     * @return The datastore set key
     */
    function getInventoryERC721ContractSetKey(InventoryTokenERC721Id inventoryId)
        public
        pure
        returns (DatastoreSetIdAddress)
    {
        return DatastoreSetIdAddress.wrap(keccak256(abi.encode(INVENTORY_ERC721_CONTRACTS_KEY, inventoryId)));
    }

    /**
     * @dev Gets the datastore set key for an inventory's ERC721 token IDs for a specific contract
     * @param inventoryId The inventory ID
     * @param nft The ERC721 contract
     * @return The datastore set key
     */
    function getInventoryERC721TokenIdSetKey(InventoryTokenERC721Id inventoryId, IERC721 nft)
        public
        pure
        returns (DatastoreSetIdUint256)
    {
        return DatastoreSetIdUint256.wrap(keccak256(abi.encode(INVENTORY_ERC721_TOKEN_IDS_KEY, inventoryId, nft)));
    }

    /**
     * @dev Checks if an inventory has a specific NFT token
     * @param inventoryId The inventory ID
     * @param nft The ERC721 contract
     * @param tokenId The token ID
     * @return True if the inventory has the token
     */
    function hasToken(InventoryTokenERC721Id inventoryId, IERC721 nft, uint256 tokenId) external view returns (bool) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().contains(
            address(this), getInventoryERC721TokenIdSetKey(inventoryId, nft), tokenId
        );
    }

    /**
     * @dev Gets all NFT contracts held by an inventory
     * @param inventoryId The inventory ID
     * @return Array of NFT contract addresses
     */
    function getInventoryNftContracts(InventoryTokenERC721Id inventoryId) public view returns (address[] memory) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().getAll(
            address(this), getInventoryERC721ContractSetKey(inventoryId)
        );
    }

    /**
     * @dev Gets all token IDs for a specific NFT contract in an inventory
     * @param inventoryId The inventory ID
     * @param nft The ERC721 contract
     * @return Array of token IDs
     */
    function getInventoryTokenIds(InventoryTokenERC721Id inventoryId, IERC721 nft)
        external
        view
        returns (uint256[] memory)
    {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().getAll(
            address(this), getInventoryERC721TokenIdSetKey(inventoryId, nft)
        );
    }

    /**
     * @dev Gets the count of different NFT contracts held by an inventory
     * @param inventoryId The inventory ID
     * @return The count of NFT contract types
     */
    function getInventoryNftContractCount(InventoryTokenERC721Id inventoryId) external view returns (uint256) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().length(
            address(this), getInventoryERC721ContractSetKey(inventoryId)
        );
    }

    /**
     * @dev Gets the count of tokens for a specific NFT contract in an inventory
     * @param inventoryId The inventory ID
     * @param nft The ERC721 contract
     * @return The count of tokens
     */
    function getInventoryTokenCount(InventoryTokenERC721Id inventoryId, IERC721 nft) external view returns (uint256) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().length(
            address(this), getInventoryERC721TokenIdSetKey(inventoryId, nft)
        );
    }

    /**
     * @dev Checks if an inventory exists
     * @param inventoryId The inventory ID
     * @return True if the inventory exists
     */
    function inventoryExists(InventoryTokenERC721Id inventoryId) external view returns (bool) {
        return inventoryMetadata[inventoryId].exists;
    }

    /**
     * @dev Gets inventory metadata
     * @param inventoryId The inventory ID
     * @return metadata The inventory metadata
     */
    function getInventoryMetadata(InventoryTokenERC721Id inventoryId)
        external
        view
        returns (InventoryMetadata memory)
    {
        return inventoryMetadata[inventoryId];
    }

    /**
     * @dev Generates a new unique inventory ID using nonce
     * @return inventoryId The generated inventory ID
     */
    function _generateInventoryId() private returns (InventoryTokenERC721Id inventoryId) {
        do {
            inventoryId = InventoryTokenERC721Id.wrap(_nonce);
            _nonce++;
        } while (inventoryMetadata[inventoryId].exists);

        return inventoryId;
    }

    /**
     * @dev Helper function to unwrap InventoryTokenERC721Id for external use
     * @param inventoryId The wrapped inventory ID
     * @return The unwrapped uint48 value
     */
    function unwrapInventoryId(InventoryTokenERC721Id inventoryId) external pure returns (uint48) {
        return InventoryTokenERC721Id.unwrap(inventoryId);
    }

    /**
     * @dev Helper function to wrap uint48 as InventoryTokenERC721Id for external use
     * @param value The uint48 value to wrap
     * @return The wrapped inventory ID
     */
    function wrapInventoryId(uint48 value) external pure returns (InventoryTokenERC721Id) {
        return InventoryTokenERC721Id.wrap(value);
    }
}
