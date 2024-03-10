// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    // Events
    event RaffleEnter(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;
    uint256 constant NOT_ENOUGH_ETH_SENT = 0.009 ether;
    uint256 constant ENOUGH_ETH_SENT = 0.01 ether;
    uint256 constant STARTING_BALANCE = 20e18;
    address USER = makeAddr("user");
    address USER2 = makeAddr("user2");
    uint256 constant GAS_PRICE = 1;
    uint256 constant NOT_ENOUTH_TIME_PASSED = 15;

    uint64 subscriptionId;
    bytes32 gasLane;
    uint256 interval;
    uint256 entranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        vm.deal(USER, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);
        (
            subscriptionId,
            gasLane,
            interval,
            entranceFee,
            callbackGasLimit,
            vrfCoordinatorV2,

        ) = helperConfig.activeNetworkConfig();
    }

    //////////////////////
    // constructor TEST //
    //////////////////////

    function testConstructorParametersAreCorrect() public {
        assertEq(raffle.getSubId(), 1);
        assertEq(raffle.getGasLane(), gasLane);
        assertEq(raffle.getInterval(), interval);
        assertEq(raffle.getEntranceFee(), entranceFee);
        assertEq(raffle.getCallbackGasLimit(), callbackGasLimit);
        assertEq(address(raffle.getVRFCoordinator()), vrfCoordinatorV2);
    }

    function testIfRaffleStartsInOpenState() public {
        assertEq(uint256(raffle.getRaffleState()), 0);
        // or
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); // Raffle.RaffleState.OPEN equals to 0
    }

    //////////////////////
    // enterRaffle TEST //
    //////////////////////

    function testRevertIfNotEnoughEthIsSentWithNotEnoughEth() public {
        vm.prank(USER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: NOT_ENOUGH_ETH_SENT}();
    }

    function testRevertIfNotEnoughEthIsSentWithZeroEth() public {
        vm.prank(USER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testIfPlayersArePushedToArrayAfterEnteringRaffle() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        vm.prank(USER2);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        assertEq(raffle.getPlayer(0), address(USER));
        assertEq(raffle.getPlayer(1), address(USER2));
    }

    function testRevertsIfTheStateIsNotOpen() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        vm.warp(block.timestamp + interval + 1); // move time forward
        vm.roll(block.number + 1); // move block forward
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
    }

    //////////////////////
    // checkUpkeep TEST //
    //////////////////////

    function testFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        console.log("UpkeepNeeded ==", upkeepNeeded);

        assertEq(upkeepNeeded, false);
    }

    function testFalseIfInCalculatingState() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        console.log("UpkeepNeeded ==", upkeepNeeded);

        assertEq(upkeepNeeded, false);
    }

    function testFalseIfTimeDoesntPass1() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        console.log("UpkeepNeeded ==", upkeepNeeded);

        assertEq(upkeepNeeded, false);
    }

    function testFalseIfTimeDoesntPass2() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();

        vm.warp(block.timestamp + NOT_ENOUTH_TIME_PASSED);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        console.log("UpkeepNeeded ==", upkeepNeeded);

        assertEq(upkeepNeeded, false);
    }

    function testReturnsTrueIfAllChecksAreTrue() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        console.log("UpkeepNeeded ==", upkeepNeeded);
        assertEq(upkeepNeeded, true);
    }

    ////////////////////////
    // performUpkeep TEST //
    ////////////////////////

    function testRevertIfUpkeepNeededIsNoTrue() public {
        vm.prank(USER);
        vm.expectRevert();
        raffle.performUpkeep("");
    }

    function testRaffleStatusIsCalculatingAfterSuccessfulCall() public {
        assertEq(uint256(raffle.getRaffleState()), 0);
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        assertEq(uint256(raffle.getRaffleState()), 1);
    }

    /////////////////////////////
    // fulfillRandomWords TEST //
    /////////////////////////////

    /////////////////////////////
    // getter functions TEST ////
    /////////////////////////////
    /**
     * @dev some getter functions are tested in constructor tests
     */

    function testGetRaffleState() public {
        assertEq(uint256(raffle.getRaffleState()), 0);
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        assertEq(uint256(raffle.getRaffleState()), 1);
    }

    function testGetNumWords() public {
        assertEq(raffle.getNumWords(), 1);
    }

    function testGetRequestConfirmations() public {
        assertEq(raffle.getRequestConfirmations(), 3);
    }

    // function testGetRecentWinner() public {
    //     vm.prank(USER);
    //     raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
    //     vm.warp(block.timestamp + interval + 1);
    //     vm.roll(block.number + 1);
    //     raffle.performUpkeep("");
    //     assertEq(raffle.getRecentWinner(), USER);
    // }

    function testGetPlayer() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        vm.prank(USER2);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        assertEq(raffle.getPlayer(0), USER);
        assertEq(raffle.getPlayer(1), USER2);
    }

    function testGetLastTimeStamp() public {
        assert(raffle.getLastTimeStamp() > 0);
    }

    function testGetNumberOfPlayers() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        assertEq(raffle.getNumberOfPlayers(), 1);
        vm.prank(USER2);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        assertEq(raffle.getNumberOfPlayers(), 2);
    }
}
