// SPDX-License-Identifier: GPL-3.0

/// @title Events for Infinite Auction Houses

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.13;

interface InfiniteAuctionHouseEvents {
    event AuctionCreated(
        uint256 indexed nounId,
        uint256 startTime,
        uint256 endTime
    );

    event AuctionBid(
        uint256 indexed nounId,
        address indexed sender,
        uint256 value,
        bool extended
    );

    event AuctionBidRevoked(address indexed sender, uint256 value);

    event AuctionExtended(uint256 indexed nounId, uint256 endTime);

    event AuctionSettled(
        uint256 indexed nounId,
        address winner,
        uint256 amount
    );

    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    event AuctionReservePriceUpdated(uint256 reservePrice);

    event AuctionMinBidIncrementPercentageUpdated(
        uint256 minBidIncrementPercentage
    );
}
