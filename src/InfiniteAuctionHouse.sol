// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/security/ReentrancyGuard.sol";
import "openzeppelin/security/Pausable.sol";
import "openzeppelin/access/Ownable.sol";
import "nouns/interfaces/INounsAuctionHouse.sol";

import "forge-std/Test.sol";

contract InfiniteAuctionHouse is ReentrancyGuard, Pausable, Ownable {
    // The minimum amount of time left in an auction after a new bid is created
    uint256 public timeBuffer;

    // The minimum price accepted in an auction
    uint256 public reservePrice;

    // The minimum percentage difference between the last bid amount and the current bid
    uint8 public minBidIncrementPercentage;

    // The duration of a single auction
    uint256 public duration;

    // The active auction
    INounsAuctionHouse.Auction public auction;

    struct Bid {
        uint256 amt;
        address nextBidder;
    }

    address public topBider;
    address internal constant SENTINEL_BID = address(0x1);

    mapping(address => address) bidders;
    mapping(address => Bid) public bids;

    constructor() {
        topBider = SENTINEL_BID;
    }

    function settleCurrentAndCreateNewAuction()
        external
        nonReentrant
        whenNotPaused
    {}

    function settleAuction() external nonReentrant whenPaused {}

    function createBid() external payable nonReentrant {
        INounsAuctionHouse.Auction memory _auction = auction;

        // require(block.timestamp < _auction.endTime, "Auction expired");
        require(msg.value >= reservePrice, "Must send at least reservePrice");

        // get top bid and set as current
        address currentBidder = topBider;

        Bid storage currentBid = bids[currentBidder];

        if (msg.value > currentBid.amt) {
            topBider = msg.sender;
        }

        console.log(currentBidder);
        console.log(currentBid.amt);
        console.log(currentBid.nextBidder);
        while (msg.value < currentBid.amt) {
            currentBidder = currentBid.nextBidder;
            currentBid = bids[currentBidder];
            console.log(currentBidder);
            console.log(currentBid.amt);
            console.log(currentBid.nextBidder);
        }

        bids[msg.sender] = Bid(msg.value, currentBidder);
    }

    /**
     * @dev This function should be called for bids that are not top bid as a more efficient way to
     * @dev traverse the linked list by specifying the starting point
     */
    function createBid(address prevBidder) external payable nonReentrant {}

    function revokeBid(uint256 nounId) external nonReentrant {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setTimeBuffer(uint256 timeBuffer) external onlyOwner {}

    function setReservePrice(uint256 reservePrice) external onlyOwner {}

    function setMinBidIncrementPercentage(uint8 minBidIncrementPercentage)
        external
        onlyOwner
    {}

    function _createAuction() internal {}

    function _settleAuction() internal {}
}
