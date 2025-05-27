// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.30;

library EntityLib {
    // Custom type definitions
    type EntityType is bytes1;
    type EntityId is uint32;
    type Entity is bytes6;

    // Constants for bit manipulation
    uint256 private constant TYPE_BITS = 8; // 2^8 (256) max entity types
    uint256 private constant ID_BITS = 32; // 2^32 (4.294967296e9) max entity ids per type

    // Error definitions
    error InvalidEntityType();
    error InvalidEntityId();

    /**
     * @dev Encodes an entity type and id into a bytes6
     * @param entityType The type of the entity (1 byte)
     * @param entityId The id of the entity (4 bytes)
     * @return The encoded entity as bytes6
     */
    function encodeEntity(EntityType entityType, EntityId entityId) internal pure returns (Entity) {
        return Entity.wrap(bytes6(abi.encodePacked(entityType, entityId)));
    }

    /**
     * @dev Decodes a bytes6 entity into its type and id components
     * @param entity The encoded entity as bytes6
     * @return entityType The type of the entity (1 byte)
     * @return entityId The id of the entity (4 bytes)
     */
    function decodeEntity(Entity entity) internal pure returns (EntityType entityType, EntityId entityId) {
        bytes6 encoded = Entity.unwrap(entity);
        entityType = EntityType.wrap(bytes1(encoded >> ID_BITS));
        entityId = EntityId.wrap(uint32(bytes4(encoded)));
    }

    /**
     * @dev Gets the type component from an encoded entity
     * @param entity The encoded entity as bytes6
     * @return The entity type (1 byte)
     */
    function getEntityType(Entity entity) internal pure returns (EntityType) {
        bytes6 encoded = Entity.unwrap(entity);
        return EntityType.wrap(bytes1(encoded >> ID_BITS));
    }

    /**
     * @dev Gets the id component from an encoded entity
     * @param entity The encoded entity as bytes6
     * @return The entity id (4 bytes)
     */
    function getEntityId(Entity entity) internal pure returns (EntityId) {
        bytes6 encoded = Entity.unwrap(entity);
        return EntityId.wrap(uint32(bytes4(encoded)));
    }
}
