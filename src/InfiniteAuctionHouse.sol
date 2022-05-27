// SPDX-License-Identifier: GPL-3.0

/// @title Infinite Auction House created for @NounsPropHouse

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

// LICENSE
// InfiniteAuctionHouse.sol is a modified version of NounsDao NounsAuctionHouse which is a modification of Zora's AuctionHouse.sol:
// https://github.com/ourzora/auction-house/blob/54a12ec1a6cf562e49f0a4917990474b11350a2d/contracts/AuctionHouse.sol
// https://github.com/nounsDAO/nouns-monorepo/blob/master/packages/nouns-contracts/contracts/NounsAuctionHouse.sol
//
// AuctionHouse.sol source code Copyright Zora licensed under the GPL-3.0 license.
// With modifications by ghard.eth

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "nouns/interfaces/INounsToken.sol";
import {IWETH} from "nouns/interfaces/IWETH.sol";

import {InfiniteAuctionHouseInterface} from "src/InfiniteAuctionHouse.interface.sol";

contract InfiniteAuctionHouse is
    ReentrancyGuard,
    Pausable,
    Ownable,
    InfiniteAuctionHouseInterface
{
    // The Nouns ERC721 token contract
    INounsToken public nouns;

    // The address of the WETH contract
    address public weth;

    // The minimum amount of time left in an auction after a new bid is created
    uint256 public timeBuffer;

    // The minimum price accepted in an auction
    uint256 public reservePrice;

    // The minimum percentage difference between the last bid amount and the current bid
    uint8 public minBidIncrementPercentage;

    // The duration of a single auction
    uint256 public duration;

    // The active auction
    Auction public auction;

    struct Bid {
        uint256 amt;
        address prevBidder;
        address nextBidder;
    }

    address internal constant SENTINEL_BID = address(0x1);

    mapping(address => Bid) public bids;

    constructor(
        INounsToken _nouns,
        address _weth,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint8 _minBidIncrementPercentage,
        uint256 _duration
    ) {
        _pause();

        // Initialize first and last bid
        bids[SENTINEL_BID] = Bid(type(uint256).max, address(0), address(0));
        bids[address(0)] = Bid(0, SENTINEL_BID, address(0));

        nouns = _nouns;
        weth = _weth;
        timeBuffer = _timeBuffer;
        reservePrice = _reservePrice;
        minBidIncrementPercentage = _minBidIncrementPercentage;
        duration = _duration;
    }

    /**
     * @notice Settle the current auction, mint a new Noun, and put it up for auction.
     */
    function settleCurrentAndCreateNewAuction()
        external
        nonReentrant
        whenNotPaused
    {
        _settleAuction();
        _createAuction();
    }

    /**
     * @notice Settle the current auction.
     * @dev This function can only be called when the contract is paused.
     */
    function settleAuction() external nonReentrant whenPaused {
        _settleAuction();
    }

    /**
     * @notice Create a bid for a Noun, with a given amount.
     * @dev This contract only accepts payment in ETH.
     */
    function createBid() external payable nonReentrant {
        _createBid(SENTINEL_BID);
    }

    /**
     * @notice Create a bid for a Noun that is less than the bid of `prevBidder`, with a given amount.
     * @dev This function should be called for bids that are not top bid as a more efficient way to
     * @dev traverse the linked list by specifying the starting point
     */
    function createBid(address prevBidder) external payable nonReentrant {
        _createBid(prevBidder);
    }

    function _createBid(address prevBidder) internal {
        Auction memory _auction = auction;

        // Require active auction to bid (in case of pausing)
        require(block.timestamp < _auction.endTime, "Auction expired");

        // remove old bid if there is one. Recycle funds.
        uint256 bidAmt = _deleteBid(msg.sender);
        bidAmt += msg.value;

        require(bidAmt >= reservePrice, "Must send at least reservePrice");

        Bid memory prevBid = bids[prevBidder];
        Bid memory nextBid = bids[prevBid.nextBidder];

        require(bidAmt <= prevBid.amt, "Invalid previous bidder");

        // check if new top bid
        bool extended;
        if (prevBidder == SENTINEL_BID && bidAmt > nextBid.amt) {
            // check that old bid was outbid by min amount
            require(
                bidAmt >=
                    nextBid.amt +
                        ((nextBid.amt * minBidIncrementPercentage) / 100),
                "Must send more than last bid by minBidIncrementPercentage amount"
            );

            // check if auction needs to be extended
            extended = _auction.endTime - block.timestamp < timeBuffer;
            if (extended) {
                auction.endTime = _auction.endTime =
                    block.timestamp +
                    timeBuffer;

                emit AuctionExtended(_auction.nounId, _auction.endTime);
            }
        }

        // LTE so those who bid same amt previously are put first
        while (bidAmt <= nextBid.amt) {
            prevBid = nextBid;
            nextBid = bids[prevBid.nextBidder];
        }

        // Should we enforce min bid increase on all bids, not just the top one?

        _insertBefore(prevBid.nextBidder, bidAmt);

        emit AuctionBid(_auction.nounId, msg.sender, bidAmt, extended);
    }

    function _insertBefore(address nextBidder, uint256 bidAmt) internal {
        Bid storage nextBid = bids[nextBidder];
        bids[msg.sender] = Bid(bidAmt, nextBid.prevBidder, nextBidder);
        bids[nextBid.prevBidder].nextBidder = msg.sender;
        nextBid.prevBidder = msg.sender;
    }

    function _deleteBid(address bidder) internal returns (uint256 amt) {
        Bid memory currentBid = bids[bidder];

        if (currentBid.amt == 0) {
            return 0;
        }

        amt = currentBid.amt;

        bids[currentBid.prevBidder].nextBidder = currentBid.nextBidder;
        bids[currentBid.nextBidder].prevBidder = currentBid.prevBidder;

        delete (bids[bidder]);
    }

    /**
     * @notice Revoke your bid and be refunded
     * @dev Cannot revoke top bid
     */
    function revokeBid() external override nonReentrant {
        require(
            bids[msg.sender].prevBidder != SENTINEL_BID,
            "Currently leading bid"
        );
        uint256 amt = _deleteBid(msg.sender);
        _safeTransferETHWithFallback(msg.sender, amt);

        emit AuctionBidRevoked(msg.sender, amt);
    }

    /**
     * @notice Pause the Nouns auction house.
     * @dev This function can only be called by the owner when the
     * contract is unpaused. While no new auctions can be started when paused,
     * anyone can settle an ongoing auction.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the Nouns auction house.
     * @dev This function can only be called by the owner when the
     * contract is paused. If required, this function will start a new auction.
     */
    function unpause() external onlyOwner {
        _unpause();

        if (auction.startTime == 0 || auction.settled) {
            _createAuction();
        }
    }

    /**
     * @notice Set the auction time buffer.
     * @dev Only callable by the owner.
     */
    function setTimeBuffer(uint256 _timeBuffer) external onlyOwner {
        timeBuffer = _timeBuffer;

        emit AuctionTimeBufferUpdated(_timeBuffer);
    }

    /**
     * @notice Set the auction reserve price.
     * @dev Only callable by the owner.
     */
    function setReservePrice(uint256 _reservePrice) external onlyOwner {
        reservePrice = _reservePrice;

        emit AuctionReservePriceUpdated(_reservePrice);
    }

    /**
     * @notice Set the auction minimum bid increment percentage.
     * @dev Only callable by the owner.
     */
    function setMinBidIncrementPercentage(uint8 _minBidIncrementPercentage)
        external
        onlyOwner
    {
        minBidIncrementPercentage = _minBidIncrementPercentage;

        emit AuctionMinBidIncrementPercentageUpdated(
            _minBidIncrementPercentage
        );
    }

    /**
     * @notice Create an auction.
     * @dev Store the auction details in the `auction` state variable and emit an AuctionCreated event.
     * If the mint reverts, the minter was updated without pausing this contract first. To remedy this,
     * catch the revert and pause this contract.
     */
    function _createAuction() internal {
        try nouns.mint() returns (uint256 nounId) {
            uint256 startTime = block.timestamp;
            uint256 endTime = startTime + duration;

            auction = Auction({
                nounId: nounId,
                startTime: startTime,
                endTime: endTime,
                settled: false
            });

            emit AuctionCreated(nounId, startTime, endTime);
        } catch Error(string memory) {
            _pause();
        }
    }

    /**
     * @notice Settle an auction, finalizing the bid and paying out to the owner.
     * @dev If there are no bids, the Noun is burned.
     */
    function _settleAuction() internal {
        Auction memory _auction = auction;

        require(_auction.startTime != 0, "Auction hasn't begun");
        require(!_auction.settled, "Auction has already been settled");
        require(
            block.timestamp >= _auction.endTime,
            "Auction hasn't completed"
        );

        auction.settled = true;

        address topBidder = bids[SENTINEL_BID].nextBidder;

        if (topBidder == address(0)) {
            nouns.burn(_auction.nounId);
        } else {
            nouns.transferFrom(address(this), topBidder, _auction.nounId);
        }

        uint256 amt = _deleteBid(topBidder);
        if (amt > 0) {
            _safeTransferETHWithFallback(owner(), amt);
        }

        emit AuctionSettled(_auction.nounId, topBidder, amt);
    }

    /**
     * @notice Transfer ETH. If the ETH transfer fails, wrap the ETH and try send it as WETH.
     */
    function _safeTransferETHWithFallback(address to, uint256 amount) internal {
        if (!_safeTransferETH(to, amount)) {
            IWETH(weth).deposit{value: amount}();
            IERC20(weth).transfer(to, amount);
        }
    }

    /**
     * @notice Transfer ETH and return the success status.
     * @dev This function only forwards 30,000 gas to the callee.
     */
    function _safeTransferETH(address to, uint256 value)
        internal
        returns (bool)
    {
        (bool success, ) = to.call{value: value, gas: 30_000}(new bytes(0));
        return success;
    }
}
