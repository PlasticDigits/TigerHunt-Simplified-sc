// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity 0.8.30;

import {EffectIndex, EffectTimestamp, IEffect} from "./IEffect.sol";
import {TargetEntity, EntityKey, EntityLib} from "../entity/EntityLib.sol";
import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

contract EffectsQueue is AccessManaged {
    using EntityLib for TargetEntity;

    //When a new effect is added, the totalEffectIndex is incremented
    mapping(EntityKey targetEntityKey => uint256 totalEffectCount) public totalEffectCount;

    //When an effect is claimed, the claimedEffectIndex is incremented
    mapping(EntityKey targetEntityKey => uint256 claimedEffectCount) public claimedEffectCount;

    mapping(EntityKey targetEntityKey => mapping(EffectIndex index => IEffect effect)) public effectImplementor;

    error NotEnoughUnclaimedEffects();

    constructor(address accessAuthority) AccessManaged(accessAuthority) {}

    function unclaimedEffectCount(TargetEntity calldata targetEntity) public view returns (uint256) {
        EntityKey targetEntityKey = targetEntity.key();
        return totalEffectCount[targetEntityKey] - claimedEffectCount[targetEntityKey];
    }

    function addEffect(TargetEntity calldata targetEntity, IEffect effect) external restricted {
        EntityKey targetEntityKey = targetEntity.key();
        effectImplementor[targetEntityKey][EffectIndex.wrap(totalEffectCount[targetEntityKey])] = effect;
        totalEffectCount[targetEntityKey]++;
    }

    function claimEffects(TargetEntity calldata targetEntity, uint256 n) external restricted {
        EntityKey targetEntityKey = targetEntity.key();
        require(n <= unclaimedEffectCount(targetEntity), NotEnoughUnclaimedEffects());
        for (uint256 i; i < n; i++) {
            effectImplementor[targetEntityKey][EffectIndex.wrap(claimedEffectCount[targetEntityKey] + i)].accept(
                EffectIndex.wrap(claimedEffectCount[targetEntityKey] + i)
            );
            delete effectImplementor[targetEntityKey][EffectIndex.wrap(claimedEffectCount[targetEntityKey] + i)];
        }
        claimedEffectCount[targetEntityKey] += n;
    }
}
