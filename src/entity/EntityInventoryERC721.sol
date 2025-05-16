// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {DatastoreSetWrapper} from "../datastore/DatastoreSetWrapper.sol";
import {DatastoreSetIdAddress} from "../datastore/DatastoreSetAddress.sol";
import {DatastoreSetIdUint256} from "../datastore/DatastoreSetUint256.sol";
import {PlayerEntity, EntityLib} from "./EntityLib.sol";
//Permisionless EntityStoreERC721
//Deposit/withdraw/transfer nfts that are stored to a particular entity
//deposit/withdraw/transfers are restricted to the entity's current location.

contract EntityInventoryERC721 is AccessManaged {
    using EntityLib for PlayerEntity;

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

    function deposit(address depositor, PlayerEntity calldata playerEntity, IERC721 _nft, uint256[] calldata _nftIds)
        external
        restricted
    {
        for (uint256 i; i < _nftIds.length; i++) {
            _nft.transferFrom(depositor, address(this), _nftIds[i]);
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().add(getEntityERC721IdSetKey(playerEntity, _nft), _nftIds[i]);
        }
        DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getEntityERC721SetKey(playerEntity), address(_nft));
    }

    function withdraw(address receiver, PlayerEntity calldata playerEntity, IERC721 _nft, uint256[] calldata _nftIds)
        external
        restricted
    {
        for (uint256 i; i < _nftIds.length; i++) {
            require(
                DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().contains(
                    address(this), getEntityERC721IdSetKey(playerEntity, _nft), _nftIds[i]
                ),
                WithdrawFailed()
            );
            _nft.transferFrom(address(this), receiver, _nftIds[i]);
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().remove(
                getEntityERC721IdSetKey(playerEntity, _nft), _nftIds[i]
            );
        }
        _removeERC721FromEntityIfBalanceIsZero(playerEntity, _nft);
    }

    function transfer(
        PlayerEntity calldata playerEntity,
        PlayerEntity calldata targetEntity,
        IERC721 _nft,
        uint256[] calldata _nftIds
    ) external restricted {
        for (uint256 i; i < _nftIds.length; i++) {
            require(
                DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().contains(
                    address(this), getEntityERC721IdSetKey(playerEntity, _nft), _nftIds[i]
                ),
                TransferFailed()
            );

            //Remove nft for player entity
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().remove(
                getEntityERC721IdSetKey(playerEntity, _nft), _nftIds[i]
            );
            _removeERC721FromEntityIfBalanceIsZero(playerEntity, _nft);

            //Add nft for target entity
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().add(getEntityERC721IdSetKey(targetEntity, _nft), _nftIds[i]);
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().add(getEntityERC721SetKey(targetEntity), address(_nft));
        }
    }

    function burn(PlayerEntity calldata playerEntity, ERC721Burnable _nft, uint256[] calldata _nftIds)
        external
        restricted
    {
        for (uint256 i; i < _nftIds.length; i++) {
            require(
                DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().contains(
                    address(this), getEntityERC721IdSetKey(playerEntity, _nft), _nftIds[i]
                ),
                BurnFailed()
            );
            _nft.burn(_nftIds[i]);
        }
        _removeERC721FromEntityIfBalanceIsZero(playerEntity, _nft);
    }

    function _removeERC721FromEntityIfBalanceIsZero(PlayerEntity calldata playerEntity, IERC721 _nft) internal {
        if (
            DATASTORE_SET_WRAPPER.DATASTORE_SET_UINT256().length(
                address(this), getEntityERC721IdSetKey(playerEntity, _nft)
            ) == 0
        ) {
            DATASTORE_SET_WRAPPER.DATASTORE_SET_ADDRESS().remove(getEntityERC721SetKey(playerEntity), address(_nft));
        }
    }

    function getEntityERC721SetKey(PlayerEntity calldata playerEntity) public pure returns (DatastoreSetIdAddress) {
        return DatastoreSetIdAddress.wrap(keccak256(abi.encode(ENTITY_ERC721_KEY_PARTIAL, playerEntity)));
    }

    function getEntityERC721IdSetKey(PlayerEntity calldata playerEntity, IERC721 _nft)
        public
        pure
        returns (DatastoreSetIdUint256)
    {
        return DatastoreSetIdUint256.wrap(keccak256(abi.encode(ENTITY_ERC721_ID_SET_KEY_PARTIAL, playerEntity, _nft)));
    }
}
