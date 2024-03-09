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

        assertEq(upkeepNeeded, false);
    }

    function testFalseIfInCalculatingState() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assertEq(upkeepNeeded, false);
    }

    function testFailsIfNotEnoughTimePassed() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();

        vm.warp(block.timestamp + 20);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        console.log("UpkeepNeeded ==", upkeepNeeded);

        assert(upkeepNeeded == true);
    }

    function testReturnsTrueIfAllChecksAreTrue() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
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
}
