// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdAddress} from "../datastore/DatastoreSetAddress.sol";

/**
 * @title SystemInventoryTokenERC20
 * @dev System for managing ERC20 token inventories in the ECS architecture
 * @notice Handles deposit, withdraw, transfer, and burn operations for ERC20 tokens
 * @notice Uses share-based accounting to handle rebasing, tax, and liquid staking tokens
 * @notice Operates on InventoryTokenERC20Id rather than EntityId for maximum composability
 * @notice Inventory IDs can be linked to entities via components, shared between entities, or exist independently
 */
contract SystemInventoryTokenERC20 is AccessManaged {
    using SafeERC20 for IERC20;

    // Custom type for inventory identification
    type InventoryTokenERC20Id is uint48;

    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;

    // Registry key for ERC20 tokens stored by inventories
    bytes32 public constant INVENTORY_ERC20_TOKENS_KEY = keccak256("INVENTORY_ERC20_TOKENS");

    // Inventory ERC20 share balances: inventoryId => token => shares
    mapping(InventoryTokenERC20Id inventoryId => mapping(IERC20 token => uint256 shares)) public inventoryERC20Shares;

    // Total shares per token (necessary for rebasing, tax, liquid staking tokens)
    mapping(IERC20 token => uint256 totalShares) public totalShares;

    // Inventory metadata
    mapping(InventoryTokenERC20Id inventoryId => InventoryMetadata metadata) public inventoryMetadata;

    // Initial precision for shares per token calculation
    uint256 public constant SHARES_PRECISION = 10 ** 8;

    // Nonce for generating new inventory IDs
    uint48 private _nonce;

    struct InventoryMetadata {
        bool exists;
        string name; // Optional human-readable name
        address creator; // Who created this inventory
        uint256 createdAt; // Block timestamp of creation
    }

    // Events
    event InventoryCreated(InventoryTokenERC20Id indexed inventoryId, address indexed creator, string name);
    event InventoryDestroyed(InventoryTokenERC20Id indexed inventoryId);
    event ERC20Deposited(
        InventoryTokenERC20Id indexed inventoryId, IERC20 indexed token, uint256 amount, uint256 shares
    );
    event ERC20Withdrawn(
        InventoryTokenERC20Id indexed inventoryId, IERC20 indexed token, uint256 amount, uint256 shares
    );
    event ERC20Transferred(
        InventoryTokenERC20Id indexed fromInventoryId,
        InventoryTokenERC20Id indexed toInventoryId,
        IERC20 indexed token,
        uint256 amount,
        uint256 shares
    );
    event ERC20Burned(InventoryTokenERC20Id indexed inventoryId, IERC20 indexed token, uint256 amount, uint256 shares);
    event ERC20Recovered(IERC20 indexed token, address indexed to, uint256 amount);

    // Errors
    error SystemInventoryTokenERC20_InventoryNotFound();
    error SystemInventoryTokenERC20_InventoryAlreadyExists();
    error SystemInventoryTokenERC20_InsufficientBalance();
    error SystemInventoryTokenERC20_InvalidAmount();
    error SystemInventoryTokenERC20_InventoryNotEmpty();

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
    function createInventory(InventoryTokenERC20Id inventoryId, string calldata name)
        external
        restricted
        returns (InventoryTokenERC20Id newInventoryId)
    {
        newInventoryId = inventoryId;

        // Generate ID if not provided
        if (InventoryTokenERC20Id.unwrap(inventoryId) == 0) {
            newInventoryId = _generateInventoryId();
        }

        require(!inventoryMetadata[newInventoryId].exists, SystemInventoryTokenERC20_InventoryAlreadyExists());

        inventoryMetadata[newInventoryId] =
            InventoryMetadata({exists: true, name: name, creator: _msgSender(), createdAt: block.timestamp});

        emit InventoryCreated(newInventoryId, _msgSender(), name);
        return newInventoryId;
    }

    /**
     * @dev Destroys an inventory (must be empty)
     * @param inventoryId The inventory identifier to destroy
     */
    function destroyInventory(InventoryTokenERC20Id inventoryId) external restricted {
        require(inventoryMetadata[inventoryId].exists, SystemInventoryTokenERC20_InventoryNotFound());

        // Check that inventory is empty
        address[] memory tokens = getInventoryTokens(inventoryId);
        require(tokens.length == 0, SystemInventoryTokenERC20_InventoryNotEmpty());

        delete inventoryMetadata[inventoryId];
        emit InventoryDestroyed(inventoryId);
    }

    /**
     * @dev Deposits ERC20 tokens into an inventory
     * @param depositor Address providing the tokens
     * @param inventoryId The inventory receiving the tokens
     * @param token The ERC20 token to deposit
     * @param amount The amount of tokens to deposit
     */
    function deposit(address depositor, InventoryTokenERC20Id inventoryId, IERC20 token, uint256 amount)
        external
        restricted
    {
        require(inventoryMetadata[inventoryId].exists, SystemInventoryTokenERC20_InventoryNotFound());
        require(amount > 0, SystemInventoryTokenERC20_InvalidAmount());

        uint256 expectedShares = convertTokensToShares(token, amount);
        uint256 initialBalance = token.balanceOf(address(this));

        token.safeTransferFrom(depositor, address(this), amount);

        // Calculate actual tokens received (may differ due to transfer tax/burn or rebasing)
        uint256 actualReceived = token.balanceOf(address(this)) - initialBalance;
        uint256 actualShares = (actualReceived * expectedShares) / amount;

        inventoryERC20Shares[inventoryId][token] += actualShares;
        totalShares[token] += actualShares;

        // Add token to inventory's ERC20 set if this is the first deposit
        if (inventoryERC20Shares[inventoryId][token] == actualShares) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getInventoryERC20SetKey(inventoryId), address(token));
        }

        emit ERC20Deposited(inventoryId, token, actualReceived, actualShares);
    }

    /**
     * @dev Withdraws ERC20 tokens from an inventory
     * @param receiver Address to receive the tokens
     * @param inventoryId The inventory providing the tokens
     * @param token The ERC20 token to withdraw
     * @param amount The amount of tokens to withdraw
     */
    function withdraw(address receiver, InventoryTokenERC20Id inventoryId, IERC20 token, uint256 amount)
        external
        restricted
    {
        require(inventoryMetadata[inventoryId].exists, SystemInventoryTokenERC20_InventoryNotFound());
        require(amount > 0, SystemInventoryTokenERC20_InvalidAmount());

        uint256 shares = convertTokensToShares(token, amount);

        require(inventoryERC20Shares[inventoryId][token] >= shares, SystemInventoryTokenERC20_InsufficientBalance());

        inventoryERC20Shares[inventoryId][token] -= shares;
        totalShares[token] -= shares;

        token.safeTransfer(receiver, amount);

        // Remove token from inventory's ERC20 set if balance is now zero
        if (inventoryERC20Shares[inventoryId][token] == 0) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(getInventoryERC20SetKey(inventoryId), address(token));
        }

        emit ERC20Withdrawn(inventoryId, token, amount, shares);
    }

    /**
     * @dev Transfers ERC20 tokens between inventories
     * @param fromInventoryId The inventory providing the tokens
     * @param toInventoryId The inventory receiving the tokens
     * @param token The ERC20 token to transfer
     * @param amount The amount of tokens to transfer
     */
    function transfer(
        InventoryTokenERC20Id fromInventoryId,
        InventoryTokenERC20Id toInventoryId,
        IERC20 token,
        uint256 amount
    ) external restricted {
        require(inventoryMetadata[fromInventoryId].exists, SystemInventoryTokenERC20_InventoryNotFound());
        require(inventoryMetadata[toInventoryId].exists, SystemInventoryTokenERC20_InventoryNotFound());
        require(amount > 0, SystemInventoryTokenERC20_InvalidAmount());

        uint256 shares = convertTokensToShares(token, amount);

        require(inventoryERC20Shares[fromInventoryId][token] >= shares, SystemInventoryTokenERC20_InsufficientBalance());

        inventoryERC20Shares[fromInventoryId][token] -= shares;
        inventoryERC20Shares[toInventoryId][token] += shares;

        // Add token to receiving inventory's ERC20 set if this is the first transfer
        if (inventoryERC20Shares[toInventoryId][token] == shares) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getInventoryERC20SetKey(toInventoryId), address(token));
        }

        // Remove token from sending inventory's ERC20 set if balance is now zero
        if (inventoryERC20Shares[fromInventoryId][token] == 0) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(
                getInventoryERC20SetKey(fromInventoryId), address(token)
            );
        }

        emit ERC20Transferred(fromInventoryId, toInventoryId, token, amount, shares);
    }

    /**
     * @dev Burns ERC20 tokens from an inventory
     * @param inventoryId The inventory providing the tokens to burn
     * @param token The burnable ERC20 token
     * @param amount The amount of tokens to burn
     */
    function burn(InventoryTokenERC20Id inventoryId, ERC20Burnable token, uint256 amount) external restricted {
        require(inventoryMetadata[inventoryId].exists, SystemInventoryTokenERC20_InventoryNotFound());
        require(amount > 0, SystemInventoryTokenERC20_InvalidAmount());

        uint256 shares = convertTokensToShares(token, amount);

        require(inventoryERC20Shares[inventoryId][token] >= shares, SystemInventoryTokenERC20_InsufficientBalance());

        inventoryERC20Shares[inventoryId][token] -= shares;
        totalShares[token] -= shares;

        token.burn(amount);

        // Remove token from inventory's ERC20 set if balance is now zero
        if (inventoryERC20Shares[inventoryId][token] == 0) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(getInventoryERC20SetKey(inventoryId), address(token));
        }

        emit ERC20Burned(inventoryId, token, amount, shares);
    }

    /**
     * @dev Converts token amount to shares for accounting
     * @param token The ERC20 token
     * @param amount The token amount
     * @return The equivalent shares
     */
    function convertTokensToShares(IERC20 token, uint256 amount) public view returns (uint256) {
        if (totalShares[token] == 0) return amount * SHARES_PRECISION;
        return (amount * totalShares[token]) / token.balanceOf(address(this));
    }

    /**
     * @dev Gets the token balance for an inventory
     * @param inventoryId The inventory ID
     * @param token The ERC20 token
     * @return The token balance
     */
    function getInventoryTokenBalance(InventoryTokenERC20Id inventoryId, IERC20 token)
        external
        view
        returns (uint256)
    {
        if (totalShares[token] == 0) return 0;
        return (inventoryERC20Shares[inventoryId][token] * token.balanceOf(address(this))) / totalShares[token];
    }

    /**
     * @dev Gets the shares per token ratio
     * @param token The ERC20 token
     * @return The shares per token ratio
     */
    function getSharesPerToken(IERC20 token) external view returns (uint256) {
        if (totalShares[token] == 0) return SHARES_PRECISION;
        return totalShares[token] / token.balanceOf(address(this));
    }

    /**
     * @dev Emergency recovery function for stuck tokens
     * @param token The token address to recover
     */
    function recoverERC20(IERC20 token) external restricted {
        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(_msgSender(), balance);
        emit ERC20Recovered(token, _msgSender(), balance);
    }

    /**
     * @dev Gets the datastore set key for an inventory's ERC20 tokens
     * @param inventoryId The inventory ID
     * @return The datastore set key
     */
    function getInventoryERC20SetKey(InventoryTokenERC20Id inventoryId) public pure returns (DatastoreSetIdAddress) {
        return DatastoreSetIdAddress.wrap(keccak256(abi.encode(INVENTORY_ERC20_TOKENS_KEY, inventoryId)));
    }

    /**
     * @dev Checks if an inventory has a specific token
     * @param inventoryId The inventory ID
     * @param token The ERC20 token
     * @return True if the inventory has the token
     */
    function hasToken(InventoryTokenERC20Id inventoryId, IERC20 token) external view returns (bool) {
        return inventoryERC20Shares[inventoryId][token] > 0;
    }

    /**
     * @dev Gets all tokens held by an inventory (via datastore set)
     * @param inventoryId The inventory ID
     * @return Array of token addresses
     */
    function getInventoryTokens(InventoryTokenERC20Id inventoryId) public view returns (address[] memory) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().getAll(address(this), getInventoryERC20SetKey(inventoryId));
    }

    /**
     * @dev Gets the count of different tokens held by an inventory
     * @param inventoryId The inventory ID
     * @return The count of token types
     */
    function getInventoryTokenCount(InventoryTokenERC20Id inventoryId) external view returns (uint256) {
        return DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().length(address(this), getInventoryERC20SetKey(inventoryId));
    }

    /**
     * @dev Checks if an inventory exists
     * @param inventoryId The inventory ID
     * @return True if the inventory exists
     */
    function inventoryExists(InventoryTokenERC20Id inventoryId) external view returns (bool) {
        return inventoryMetadata[inventoryId].exists;
    }

    /**
     * @dev Gets inventory metadata
     * @param inventoryId The inventory ID
     * @return metadata The inventory metadata
     */
    function getInventoryMetadata(InventoryTokenERC20Id inventoryId) external view returns (InventoryMetadata memory) {
        return inventoryMetadata[inventoryId];
    }

    /**
     * @dev Generates a new unique inventory ID using nonce
     * @return inventoryId The generated inventory ID
     */
    function _generateInventoryId() private returns (InventoryTokenERC20Id inventoryId) {
        do {
            inventoryId = InventoryTokenERC20Id.wrap(_nonce);
            _nonce++;
        } while (inventoryMetadata[inventoryId].exists);

        return inventoryId;
    }

    /**
     * @dev Helper function to unwrap InventoryTokenERC20Id for external use
     * @param inventoryId The wrapped inventory ID
     * @return The unwrapped uint48 value
     */
    function unwrapInventoryId(InventoryTokenERC20Id inventoryId) external pure returns (uint48) {
        return InventoryTokenERC20Id.unwrap(inventoryId);
    }

    /**
     * @dev Helper function to wrap uint48 as InventoryTokenERC20Id for external use
     * @param value The uint48 value to wrap
     * @return The wrapped inventory ID
     */
    function wrapInventoryId(uint48 value) external pure returns (InventoryTokenERC20Id) {
        return InventoryTokenERC20Id.wrap(value);
    }
}
