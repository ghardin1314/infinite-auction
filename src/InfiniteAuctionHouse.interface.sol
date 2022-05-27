// SPDX-License-Identifier: GPL-3.0

/// @title Interface for Infinite Auction Houses

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

import {InfiniteAuctionHouseEvents} from "./InfiniteAuctionHouse.events.sol";

interface InfiniteAuctionHouseInterface is InfiniteAuctionHouseEvents {
	
    struct Auction {
        // ID for the Noun (ERC721 token ID)
        uint256 nounId;
        // The time that the auction started
        uint256 startTime;
        // The time that the auction is scheduled to end
        uint256 endTime;
        // Whether or not the auction has been settled
        bool settled;
    }

    function settleAuction() external;

    function settleCurrentAndCreateNewAuction() external;

    function createBid() external payable;

    function createBid(address prevBidder) external payable;

    function revokeBid() external;

    function pause() external;

    function unpause() external;

    function setTimeBuffer(uint256 timeBuffer) external;

    function setReservePrice(uint256 reservePrice) external;

    function setMinBidIncrementPercentage(uint8 minBidIncrementPercentage)
        external;
}
