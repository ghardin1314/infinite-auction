// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/security/ReentrancyGuard.sol";
import "openzeppelin/security/Pausable.sol";
import "openzeppelin/access/Ownable.sol";
import "nouns/interfaces/INounsAuctionHouse.sol";

import "forge-std/Test.sol";

contract InfiniteAuctionHouse is ReentrancyGuard, Pausable, Ownable, INounsAuctionHouse {
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
        address prevBidder;
        address nextBidder;
    }

    address internal constant SENTINEL_BID = address(0x1);

    mapping(address => address) bidders;
    mapping(address => Bid) public bids;

    constructor() {
        bids[SENTINEL_BID] = Bid(type(uint256).max, address(0), address(0));
        bids[address(0)] = Bid(0, SENTINEL_BID, address(0));
    }

    function settleCurrentAndCreateNewAuction()
        external
        nonReentrant
        whenNotPaused
    {}

    function settleAuction() external nonReentrant whenPaused {}

    function createBid(uint256 nounId) external payable nonReentrant {
        INounsAuctionHouse.Auction memory _auction = auction;

        // require(block.timestamp < _auction.endTime, "Auction expired");
        require(msg.value >= reservePrice, "Must send at least reservePrice");

        _createBid(SENTINEL_BID);
       
    }

        /**
     * @dev This function should be called for bids that are not top bid as a more efficient way to
     * @dev traverse the linked list by specifying the starting point
     */
    function createBid(uint256 nounId, address prevBidder) external payable nonReentrant {

        _createBid(prevBidder);

    }

    function _createBid(address prevBidder) internal {
        // remove old bid if there is one. Recycle funds.
        uint256 bidAmt = _deleteBid(msg.sender);
        bidAmt += msg.value;
        
        console.log(bidAmt);

        // get top bid and set as current
        Bid memory prevBid = bids[prevBidder];
        Bid memory nextBid = bids[prevBid.nextBidder];

        require(bidAmt <= prevBid.amt, "Invalid previous bidder");

        if (prevBidder == SENTINEL_BID && bidAmt > nextBid.amt) {
            console.log("New Top Bid");
        }

        // Strictly less than so those who bid same amt before are first
        while (bidAmt < nextBid.amt) {
            prevBid = nextBid;
            nextBid = bids[prevBid.nextBidder];
        }

        _insertBefore(prevBid.nextBidder, bidAmt);
    }


    function _insertBefore(address nextBidder, uint256 bidAmt) internal {
        Bid storage nextBid = bids[nextBidder];
        bids[msg.sender] = Bid(bidAmt, nextBid.prevBidder, nextBidder);
        bids[nextBid.prevBidder].nextBidder = msg.sender;
        nextBid.prevBidder = msg.sender;
    }

    function _deleteBid(address bidder) internal returns (uint256 amt) {
        Bid memory currentBid = bids[bidder];

        if(currentBid.amt == 0){
            return 0;
        }

        amt = currentBid.amt;

        bids[currentBid.prevBidder].nextBidder = currentBid.nextBidder;
        bids[currentBid.nextBidder].prevBidder = currentBid.prevBidder;

        delete(bids[bidder]);
    }

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
