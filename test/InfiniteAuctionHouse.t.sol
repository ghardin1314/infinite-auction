// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/InfiniteAuctionHouse.sol";

contract InfiniteAuctionHouseTest is Test {
    InfiniteAuctionHouse auctionHouse;

    address internal constant SENTINEL_BID = address(0x1);
    address alice = address(2);
    address bob = address(3);
    address charlie = address(4);

    function setUp() public {
        auctionHouse = new InfiniteAuctionHouse();
        deal(alice, 10 ether);
        deal(bob, 10 ether);
        deal(charlie, 10 ether);
    }

    function testCreateInitialBid() public {
        uint256 amt;
        address nextBidder;
        address prevBidder;

        vm.prank(alice);
        auctionHouse.createBid{value: 1 ether}(1);

        (, , nextBidder) = auctionHouse.bids(SENTINEL_BID);
        assertEq(nextBidder, alice);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(alice);
        assertEq(prevBidder, SENTINEL_BID);
        assertEq(nextBidder, address(0));
        assertEq(amt, 1 ether);

    }

    function testCreateOutBid() public {
        uint256 amt;
        address nextBidder;
        address prevBidder;

        vm.prank(alice);
        auctionHouse.createBid{value: 1 ether}(1);

        vm.prank(bob);
        auctionHouse.createBid{value: 2 ether}(1);

        (, , nextBidder) = auctionHouse.bids(SENTINEL_BID);
        assertEq(nextBidder, bob);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(bob);
        assertEq(prevBidder, SENTINEL_BID);
        assertEq(nextBidder, alice);
        assertEq(amt, 2 ether);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(alice);
        assertEq(prevBidder, bob);
        assertEq(nextBidder, address(0));
        assertEq(amt, 1 ether);
    }

    function testCreateReOutBid() public {
        uint256 amt;
        address nextBidder;
        address prevBidder;

        vm.prank(alice);
        auctionHouse.createBid{value: 1 ether}(1);

        vm.prank(bob);
        auctionHouse.createBid{value: 2 ether}(1);

        vm.prank(alice);
        auctionHouse.createBid{value: 1.5 ether}(1);

        (, , nextBidder) = auctionHouse.bids(SENTINEL_BID);
        assertEq(nextBidder, alice);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(alice);
        assertEq(prevBidder, SENTINEL_BID);
        assertEq(nextBidder, bob);
        assertEq(amt, 2.5 ether);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(bob);
        assertEq(prevBidder, alice);
        assertEq(nextBidder, address(0));
        assertEq(amt, 2 ether);
    }

    function testCreateReMidBid() public {
        uint256 amt;
        address nextBidder;
        address prevBidder;

        vm.prank(alice);
        auctionHouse.createBid{value: 1 ether}(1);

        vm.prank(bob);
        auctionHouse.createBid{value: 2 ether}(1);

        vm.prank(alice);
        auctionHouse.createBid{value: 0.5 ether}(1);

        (, , nextBidder) = auctionHouse.bids(SENTINEL_BID);
        assertEq(nextBidder, bob);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(bob);
        assertEq(prevBidder, SENTINEL_BID);
        assertEq(nextBidder, alice);
        assertEq(amt, 2 ether);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(alice);
        assertEq(prevBidder, bob);
        assertEq(nextBidder, address(0));
        assertEq(amt, 1.5 ether);
    }

    function testCreateMidSpecifiedBid() public {
        uint256 amt;
        address nextBidder;
        address prevBidder;

        vm.prank(alice);
        auctionHouse.createBid{value: 1 ether}(1);

        vm.prank(bob);
        auctionHouse.createBid{value: 2 ether}(1);

        vm.prank(charlie);
        auctionHouse.createBid{value: 1.5 ether}(1, bob);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(bob);
        assertEq(nextBidder, charlie);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(charlie);
        assertEq(prevBidder, bob);
        assertEq(nextBidder, alice);
        assertEq(amt, 1.5 ether);


        (amt, prevBidder, nextBidder) = auctionHouse.bids(alice);
        assertEq(prevBidder, charlie);
        assertEq(nextBidder, address(0));
        assertEq(amt, 1 ether);
    }

    function testCreateFloorSpecifiedBid() public {
        uint256 amt;
        address nextBidder;
        address prevBidder;

        vm.prank(alice);
        auctionHouse.createBid{value: 1 ether}(1);

        vm.prank(bob);
        auctionHouse.createBid{value: 2 ether}(1);

        vm.prank(charlie);
        auctionHouse.createBid{value: 0.5 ether}(1, alice);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(alice);
        assertEq(nextBidder, charlie);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(charlie);
        assertEq(prevBidder, alice);
        assertEq(nextBidder, address(0));
        assertEq(amt, 0.5 ether);
    }
}
