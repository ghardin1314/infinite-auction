// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/InfiniteAuctionHouse.sol";

contract InfiniteAuctionHouseTest is Test {
    InfiniteAuctionHouse auctionHouse;

    address internal constant SENTINEL_BID = address(0x1);
    address alice = address(2);
    address bob = address(3);

    function setUp() public {
        auctionHouse = new InfiniteAuctionHouse();
        deal(alice, 10 ether);
        deal(bob, 10 ether);
    }

    function testCreateInitialBid() public {
        assertEq(auctionHouse.topBider(), SENTINEL_BID);
        vm.prank(alice);
        auctionHouse.createBid{value: 1 ether}();

        assertEq(auctionHouse.topBider(), alice);

        (uint256 amt, address nextBidder) = auctionHouse.bids(alice);
        assertEq(nextBidder, SENTINEL_BID);
        assertEq(amt, 1 ether);
    }

    function testCreateOutBid() public {
        vm.prank(alice);
        auctionHouse.createBid{value: 1 ether}();

        vm.prank(bob);
        auctionHouse.createBid{value: 2 ether}();

        assertEq(auctionHouse.topBider(), bob);

        (uint256 topBid, address nextBidder) = auctionHouse.bids(bob);
        assertEq(nextBidder, alice);
        assertEq(topBid, 2 ether);

        (uint256 lessBid, address lastBidder) = auctionHouse.bids(alice);
        assertEq(lastBidder, SENTINEL_BID);
        assertEq(lessBid, 1 ether);
    }
}
