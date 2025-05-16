// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdAddress} from "../datastore/DatastoreSetAddress.sol";
import {DatastoreSetIdUint256} from "../datastore/DatastoreSetUint256.sol";
//Permisionless EntityStoreERC721
//Deposit/withdraw/transfer nfts that are stored to a particular entity
//deposit/withdraw/transfers are restricted to the entity's current location.

contract EntityInventoryERC721 is AccessManaged {
    DatastoreSetWrapper public immutable DATASTORE_SET_WRAPPER;

    bytes32 public constant ENTITY_ERC721_KEY_PARTIAL = keccak256("ENTITY_ERC721_KEY_PARTIAL");
    bytes32 public constant ENTITY_ERC721_ID_SET_KEY_PARTIAL = keccak256("ENTITY_ERC721_ID_SET_KEY_PARTIAL");

    error TransferFailed();
    error DepositFailed();
    error WithdrawFailed();
    error BurnFailed();

    constructor(DatastoreSetWrapper datastoreSetWrapper, address accessAuthority) AccessManaged(accessAuthority) {
        DATASTORE_SET_WRAPPER = datastoreSetWrapper;
    }

    function deposit(address depositor, IERC721 _entity, uint256 _entityId, IERC721 _nft, uint256[] calldata _nftIds)
        external
        restricted
    {
        for (uint256 i; i < _nftIds.length; i++) {
            _nft.transferFrom(depositor, address(this), _nftIds[i]);
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().add(
                getEntityERC721IdSetKey(_entity, _entityId, _nft), _nftIds[i]
            );
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getEntityERC721SetKey(_entity, _entityId), address(_nft));
        }
    }

    function withdraw(address receiver, IERC721 _entity, uint256 _entityId, IERC721 _nft, uint256[] calldata _nftIds)
        external
        restricted
    {
        for (uint256 i; i < _nftIds.length; i++) {
            require(
                DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().contains(
                    address(this), getEntityERC721IdSetKey(_entity, _entityId, _nft), _nftIds[i]
                ),
                WithdrawFailed()
            );
            _nft.transferFrom(address(this), receiver, _nftIds[i]);
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().remove(
                getEntityERC721IdSetKey(_entity, _entityId, _nft), _nftIds[i]
            );
        }
        _removeERC721FromEntityIfBalanceIsZero(_entity, _entityId, _nft);
    }

    function transfer(
        IERC721 _fromEntity,
        uint256 _fromEntityId,
        IERC721 _toEntity,
        uint256 _toEntityId,
        IERC721 _nft,
        uint256[] calldata _nftIds
    ) external restricted {
        for (uint256 i; i < _nftIds.length; i++) {
            require(
                DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().contains(
                    address(this), getEntityERC721IdSetKey(_fromEntity, _fromEntityId, _nft), _nftIds[i]
                ),
                TransferFailed()
            );

            //Remove nft for from entity
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().remove(
                getEntityERC721IdSetKey(_fromEntity, _fromEntityId, _nft), _nftIds[i]
            );
            _removeERC721FromEntityIfBalanceIsZero(_fromEntity, _fromEntityId, _nft);

            //Add nft for to entity
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().add(
                getEntityERC721IdSetKey(_toEntity, _toEntityId, _nft), _nftIds[i]
            );
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(
                getEntityERC721SetKey(_toEntity, _toEntityId), address(_nft)
            );
        }
    }

    function burn(IERC721 _entity, uint256 _entityId, ERC721Burnable _nft, uint256[] calldata _nftIds)
        external
        restricted
    {
        for (uint256 i; i < _nftIds.length; i++) {
            require(
                DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().contains(
                    address(this), getEntityERC721IdSetKey(_entity, _entityId, _nft), _nftIds[i]
                ),
                BurnFailed()
            );
            _nft.burn(_nftIds[i]);
        }
        _removeERC721FromEntityIfBalanceIsZero(_entity, _entityId, _nft);
    }

    function _removeERC721FromEntityIfBalanceIsZero(IERC721 _entity, uint256 _entityId, IERC721 _nft) internal {
        if (
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().length(
                address(this), getEntityERC721IdSetKey(_entity, _entityId, _nft)
            ) == 0
        ) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(
                getEntityERC721SetKey(_entity, _entityId), address(_nft)
            );
        }
    }

    function getEntityERC721SetKey(IERC721 _entity, uint256 _entityId) public pure returns (DatastoreSetIdAddress) {
        return DatastoreSetIdAddress.wrap(keccak256(abi.encodePacked(ENTITY_ERC721_KEY_PARTIAL, _entity, _entityId)));
    }

    function getEntityERC721IdSetKey(IERC721 _entity, uint256 _entityId, IERC721 _nft)
        public
        pure
        returns (DatastoreSetIdUint256)
    {
        return DatastoreSetIdUint256.wrap(
            keccak256(abi.encodePacked(ENTITY_ERC721_ID_SET_KEY_PARTIAL, _entity, _entityId, _nft))
        );
    }
}
