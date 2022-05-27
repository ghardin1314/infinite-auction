// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {InfiniteAuctionHouseEvents} from "src/InfiniteAuctionHouse.events.sol";
import {InfiniteAuctionHouse} from "src/InfiniteAuctionHouse.sol";

import "src/NounTokenMock.sol";

import "nouns/test/WETH.sol";

contract Base is Test, InfiniteAuctionHouseEvents {
    uint256 TIME_BUFFER = 15 * 60;
    uint256 RESERVE_PRICE = 2;
    uint8 MIN_INCREMENT_BID_PERCENTAGE = 5;
    uint256 DURATION = 60 * 60 * 24;

    InfiniteAuctionHouse auctionHouse;
    INounsToken nouns;
    WETH weth;

    address internal constant SENTINEL_BID = address(0x1);
    address alice = address(2);
    address bob = address(3);
    address charlie = address(4);
    address daniel = address(5);

    function setUp() public virtual {
        weth = new WETH();

        nouns = INounsToken(address(new NounTokenMock()));

        auctionHouse = new InfiniteAuctionHouse(
            nouns,
            address(weth),
            TIME_BUFFER,
            RESERVE_PRICE,
            MIN_INCREMENT_BID_PERCENTAGE,
            DURATION
        );

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(daniel, "Daniel");

        deal(alice, 10 ether);
        deal(bob, 10 ether);
        deal(charlie, 10 ether);
        deal(daniel, 10 ether);
    }

    function createBidAs(address bidder, uint256 amt) internal {
        vm.prank(bidder);
        auctionHouse.createBid{value: amt}();
    }

    function createBidAs(
        address bidder,
        uint256 amt,
        address prevBidder
    ) internal {
        vm.prank(bidder);
        auctionHouse.createBid{value: amt}(prevBidder);
    }

    receive() external payable {}
}

contract WhenAuctionLive is Base {
    uint256 internal amt;
    address internal nextBidder;
    address internal prevBidder;

    function setUp() public virtual override {
        Base.setUp();
        auctionHouse.unpause();
    }
}

contract WhenStartingAuction is Base {
    function setUp() public override {
        Base.setUp();
    }

    function testOwnerCanUnpauseAndStart() public {
        auctionHouse.unpause();

        (, uint256 startTime, uint256 endTime, ) = auctionHouse.auction();
        assertTrue(startTime > 0);
        assertEq(startTime + DURATION, endTime);
    }

    function testNoBidsBeforeStart() public {
        vm.expectRevert("Auction expired");
        auctionHouse.createBid();
    }
}

contract WhenCreatingInitialBid is WhenAuctionLive {
    function setUp() public virtual override {
        WhenAuctionLive.setUp();
    }

    function testCannotBidBelowReserve() public {
        vm.expectRevert("Must send at least reservePrice");
        createBidAs(alice, RESERVE_PRICE - 1);
    }

    function testCannotBidAfterAuction() public {
        (, , uint256 oldEndTime, ) = auctionHouse.auction();
        vm.warp(oldEndTime + 1);

        vm.expectRevert("Auction expired");
        createBidAs(alice, 1 ether);
    }

    function testCanPlaceTopBid() public {
        vm.expectEmit(true, true, false, true, address(auctionHouse));
        emit AuctionBid(1, alice, 1 ether, false);

        createBidAs(alice, 1 ether);

        (, , nextBidder) = auctionHouse.bids(SENTINEL_BID);
        assertEq(nextBidder, alice);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(alice);
        assertEq(prevBidder, SENTINEL_BID);
        assertEq(nextBidder, address(0));
        assertEq(amt, 1 ether);
        assertEq(address(auctionHouse).balance, 1 ether);
    }

    function testCanIncreaseBid() public {
        testCanPlaceTopBid();

        createBidAs(alice, 0.5 ether);
        (amt, , ) = auctionHouse.bids(alice);
        assertEq(amt, 1.5 ether);
    }
}

contract WhenPlacingNewTopBid is WhenAuctionLive {
    function setUp() public virtual override {
        WhenAuctionLive.setUp();
        createBidAs(alice, 1 ether);
    }

    function testCanOutBid() public {
        createBidAs(bob, 2 ether);

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

    function testMustBidMinIncrease() public {
        vm.expectRevert(
            "Must send more than last bid by minBidIncrementPercentage amount"
        );
        createBidAs(bob, 1 ether + 1);
    }

    function testCanReOutBid() public {
        createBidAs(bob, 2 ether);

        createBidAs(alice, 1.5 ether);

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

    function testOutBidExtendsAuction() public {
        (, , uint256 oldEndTime, ) = auctionHouse.auction();

        uint256 newTime = oldEndTime - 1;
        vm.warp(newTime);

        vm.expectEmit(true, false, false, true, address(auctionHouse));
        emit AuctionExtended(1, newTime + TIME_BUFFER);

        vm.expectEmit(true, true, false, true, address(auctionHouse));
        emit AuctionBid(1, bob, 2 ether, true);

        createBidAs(bob, 2 ether);
        (, , uint256 newEndTime, ) = auctionHouse.auction();

        assertEq(newEndTime, newTime + TIME_BUFFER);
    }
}

contract WhenPlacingNonTopBid is WhenAuctionLive {
    function setUp() public virtual override {
        WhenAuctionLive.setUp();
        createBidAs(alice, 1 ether);
        createBidAs(bob, 2 ether);
    }

    function testCanPlaceBetweenBids() public {
        createBidAs(charlie, 1.5 ether, bob);

        (, , nextBidder) = auctionHouse.bids(bob);
        assertEq(nextBidder, charlie);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(charlie);
        assertEq(prevBidder, bob);
        assertEq(nextBidder, alice);
        assertEq(amt, 1.5 ether);

        (, prevBidder, ) = auctionHouse.bids(alice);
        assertEq(prevBidder, charlie);
    }

    function testCanPlaceFloorBids() public {
        createBidAs(charlie, 0.5 ether, alice);

        (, , nextBidder) = auctionHouse.bids(alice);
        assertEq(nextBidder, charlie);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(charlie);
        assertEq(prevBidder, alice);
        assertEq(nextBidder, address(0));
        assertEq(amt, 0.5 ether);
    }

    function testCanSpecifyAnyHigherBidder() public {
        createBidAs(charlie, 0.5 ether, bob);

        (, , nextBidder) = auctionHouse.bids(alice);
        assertEq(nextBidder, charlie);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(charlie);
        assertEq(prevBidder, alice);
        assertEq(nextBidder, address(0));
        assertEq(amt, 0.5 ether);
    }

    function testLaterBidPutLast() public {
        createBidAs(charlie, 0.5 ether, alice);
        createBidAs(daniel, 0.5 ether, alice);

        (, , nextBidder) = auctionHouse.bids(alice);
        assertEq(nextBidder, charlie);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(charlie);
        assertEq(nextBidder, daniel);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(daniel);
        assertEq(prevBidder, charlie);
        assertEq(nextBidder, address(0));
    }

    function testMustSpecifyHigherBid() public {
        vm.expectRevert("Invalid previous bidder");
        createBidAs(charlie, 1.5 ether, alice);
    }
}

contract WhenRevokingBid is WhenAuctionLive {
    function setUp() public virtual override {
        WhenAuctionLive.setUp();
        createBidAs(alice, 1 ether);
    }

    function testCantRevokeTopBid() public {
        vm.prank(alice);
        vm.expectRevert("Currently leading bid");
        auctionHouse.revokeBid();
    }

    function testCanRevokeNonTopBid() public {
        createBidAs(bob, 2 ether);

        uint256 prevBal = alice.balance;
        vm.prank(alice);
        auctionHouse.revokeBid();
        assertEq(prevBal + 1 ether, alice.balance);
        assertEq(address(auctionHouse).balance, 2 ether);
    }
}

contract WhenSettlingAuction is WhenAuctionLive {
    function setUp() public virtual override {
        WhenAuctionLive.setUp();
        createBidAs(alice, 1 ether);
        createBidAs(bob, 2 ether);
        (, , uint256 endTime, ) = auctionHouse.auction();
        vm.warp(endTime + 1);
    }

    function testSettlingAuctionPopsTopBid() public {
        uint256 prevOwnerBal = address(this).balance;

        vm.expectEmit(true, false, false, true, address(auctionHouse));
        emit AuctionSettled(1, bob, 2 ether);

        auctionHouse.settleCurrentAndCreateNewAuction();

        (, , nextBidder) = auctionHouse.bids(SENTINEL_BID);
        assertEq(nextBidder, alice);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(alice);
        assertEq(prevBidder, SENTINEL_BID);

        assertEq(address(this).balance, prevOwnerBal + 2 ether);

        (amt, prevBidder, nextBidder) = auctionHouse.bids(bob);
        assertEq(prevBidder, address(0));
        assertEq(nextBidder, address(0));
        assertEq(amt, 0);
    }

    function testNounTransferredToWinner() public {
        vm.expectCall(
            address(nouns),
            abi.encodeCall(nouns.transferFrom, (address(auctionHouse), bob, 1))
        );

        auctionHouse.settleCurrentAndCreateNewAuction();
    }

    function testNextAuctionStarted() public {
        vm.expectEmit(true, false, false, true, address(auctionHouse));
        emit AuctionCreated(1, block.timestamp, block.timestamp + DURATION);

        auctionHouse.settleCurrentAndCreateNewAuction();
    }

    function testSettlingSequentialAuctions() public {
        uint256 prevOwnerBal = address(this).balance;

        auctionHouse.settleCurrentAndCreateNewAuction();
        (, , uint256 endTime, ) = auctionHouse.auction();
        vm.warp(endTime + 1);
        auctionHouse.settleCurrentAndCreateNewAuction();

        assertEq(address(this).balance, prevOwnerBal + 3 ether);

        (, , nextBidder) = auctionHouse.bids(SENTINEL_BID);
        assertEq(nextBidder, address(0));
    }
}
