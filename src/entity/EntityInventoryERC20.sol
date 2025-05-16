// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.30;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdAddress} from "../datastore/DatastoreSetAddress.sol";
//EntityInventoryERC20
//Deposit/withdraw/transfer tokens that are stored to a particular entity

contract EntityInventoryERC20 is AccessManaged {
    using SafeERC20 for IERC20;

    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;

    //Key for which ERC20s are stored by a specific entity
    bytes32 public constant ENTITY_ERC20_KEY_PARTIAL = keccak256("ENTITY_ERC20_KEY_PARTIAL");

    mapping(IERC721 entity => mapping(uint256 entityId => mapping(IERC20 token => uint256 shares)))
        entityStoredERC20Shares;
    //Neccessary for rebasing, tax, liquid staking, or other tokens
    //that may directly modify this contract's balance.
    mapping(IERC20 token => uint256 totalShares) public totalShares;
    //Initial precision for shares per token
    uint256 constant SHARES_PRECISION = 10 ** 8;

    constructor(DatastoreSetWrapper datastoreSetWrapper, address accessAuthority) AccessManaged(accessAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
    }

    function deposit(address depositor, IERC721 _entity, uint256 _entityId, IERC20 _token, uint256 _wad)
        external
        restricted
    {
        uint256 expectedShares = convertTokensToShares(_token, _wad);
        uint256 initialTokens = _token.balanceOf(address(this));
        _token.safeTransferFrom(depositor, address(this), _wad);
        //May be different than _wad due to transfer tax/burn or rebasing
        uint256 deltaTokens = _token.balanceOf(address(this)) - initialTokens;
        uint256 newShares = (deltaTokens * expectedShares) / _wad;
        entityStoredERC20Shares[_entity][_entityId][_token] += newShares;
        totalShares[_token] += newShares;
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getEntityERC20SetKey(_entity, _entityId), address(_token));
    }

    function withdraw(address receiver, IERC721 _entity, uint256 _entityId, IERC20 _token, uint256 _wad)
        external
        restricted
    {
        uint256 shares = convertTokensToShares(_token, _wad);
        entityStoredERC20Shares[_entity][_entityId][_token] -= shares;
        totalShares[_token] -= shares;
        _token.safeTransfer(receiver, _wad);
        //if the balance of this erc20 is 0 for this entity now, remove it from the set
        if (entityStoredERC20Shares[_entity][_entityId][_token] == 0) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(
                getEntityERC20SetKey(_entity, _entityId), address(_token)
            );
        }
    }

    function transfer(
        IERC721 _fromEntity,
        uint256 _fromEntityId,
        IERC721 _toEntity,
        uint256 _toEntityId,
        IERC20 _token,
        uint256 _wad
    ) external restricted {
        uint256 shares = convertTokensToShares(_token, _wad);
        entityStoredERC20Shares[_fromEntity][_fromEntityId][_token] -= shares;
        entityStoredERC20Shares[_toEntity][_toEntityId][_token] += shares;
        // add the erc20 to the receiving set
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getEntityERC20SetKey(_toEntity, _toEntityId), address(_token));
        //if the balance of this erc20 is 0 for this entity now, remove it from the set
        if (entityStoredERC20Shares[_fromEntity][_fromEntityId][_token] == 0) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(
                getEntityERC20SetKey(_fromEntity, _fromEntityId), address(_token)
            );
        }
    }

    function burn(IERC721 _entity, uint256 _entityId, ERC20Burnable _token, uint256 _wad) external restricted {
        uint256 shares = convertTokensToShares(_token, _wad);
        entityStoredERC20Shares[_entity][_entityId][_token] -= shares;
        totalShares[_token] -= shares;
        _token.burn(_wad);
    }

    function convertTokensToShares(IERC20 _token, uint256 _wad) public view returns (uint256) {
        if (totalShares[_token] == 0) return _wad * SHARES_PRECISION;
        return (_wad * totalShares[_token]) / _token.balanceOf(address(this));
    }

    function getStoredER20WadFor(IERC721 _entity, uint256 _entityId, IERC20 _token) external view returns (uint256) {
        return (entityStoredERC20Shares[_entity][_entityId][_token] * _token.balanceOf(address(this)))
            / totalShares[_token];
    }

    function getSharesPerToken(IERC20 _token) external view returns (uint256) {
        if (totalShares[_token] == 0) return SHARES_PRECISION;
        return totalShares[_token] / _token.balanceOf(address(this));
    }

    //Escape hatch for emergency use
    function recoverERC20(address tokenAddress) external restricted {
        IERC20(tokenAddress).safeTransfer(_msgSender(), IERC20(tokenAddress).balanceOf(address(this)));
    }

    function getEntityERC20SetKey(IERC721 _entity, uint256 _entityId) public pure returns (DatastoreSetIdAddress) {
        return DatastoreSetIdAddress.wrap(keccak256(abi.encode(ENTITY_ERC20_KEY_PARTIAL, _entity, _entityId)));
    }
}
