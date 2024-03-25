// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "../../test/mock/VRFCoordinatorV2Mock.sol";

contract InteractionsTest is Test {
    // Events
    event RaffleEnter(address indexed player);

    modifier raffleEnteredAndTimeIncreased() {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    Raffle raffle;
    HelperConfig helperConfig;
    VRFCoordinatorV2Mock vrfCoordinatorV2Mock;
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
    uint256 deployerKey;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (subscriptionId, gasLane, interval, entranceFee, callbackGasLimit, vrfCoordinatorV2,, deployerKey) =
            helperConfig.activeNetworkConfig();
        vm.deal(USER, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);
    }

    //////////////////////
    // constructor TEST //
    //////////////////////

    function testConstructorParametersAreCorrect() public {
        assertEq(raffle.getSubId(), subscriptionId);
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

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        console.log("UpkeepNeeded ==", upkeepNeeded);

        assertEq(upkeepNeeded, false);
    }

    function testFalseIfInCalculatingState() public raffleEnteredAndTimeIncreased {
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        console.log("UpkeepNeeded ==", upkeepNeeded);

        assertEq(upkeepNeeded, false);
    }

    function testFalseIfNotEnoughTimePassed1() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        console.log("UpkeepNeeded ==", upkeepNeeded);

        assertEq(upkeepNeeded, false);
    }

    function testFalseIfNotEnoughTimePassed2() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();

        vm.warp(block.timestamp + NOT_ENOUTH_TIME_PASSED);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        console.log("UpkeepNeeded ==", upkeepNeeded);

        assertEq(upkeepNeeded, false);
    }

    function testReturnsTrueIfAllChecksAreTrue() public raffleEnteredAndTimeIncreased {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        console.log("UpkeepNeeded ==", upkeepNeeded);
        assertEq(upkeepNeeded, true);
    }

    ////////////////////////
    // performUpkeep TEST //
    ////////////////////////

    function testRevertIfUpkeepNeededIsNotTrue() public {
        vm.prank(USER);
        uint256 balance = 0;
        uint256 playersAmount = 0;
        uint256 raffleState = 0;
        // Revert with custom error + parameters
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, balance, playersAmount, raffleState)
        );
        raffle.performUpkeep("");
    }

    function testRaffleStatusIsCalculatingAfterSuccessfulCall() public raffleEnteredAndTimeIncreased {
        assertEq(uint256(raffle.getRaffleState()), 0);
        raffle.performUpkeep("");
        assertEq(uint256(raffle.getRaffleState()), 1);
    }

    function testPerformUpkeepEmitsRequestedId() public raffleEnteredAndTimeIncreased {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        assert(uint256(requestId) > 0);
        console.log("requestId ==", uint256(requestId));
    }

    /////////////////////////////
    // fulfillRandomWords TEST //
    /////////////////////////////
    modifier skipFork() {
        if (block.chainid != 1337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordCanOnlyBeCalledAfterPerformUpkeep(uint256 _randomRequestId)
        public
        raffleEnteredAndTimeIncreased
        skipFork
    {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(_randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksWinnerResetsAndSendMoney() public skipFork {
        uint256 playersAmount = 10;
        for (uint256 i = 1; i < playersAmount + 1; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
            // assert(raffle.getPlayer(i) == player);
        }
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 startingTimeStamp = raffle.getLastTimeStamp();

        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(uint256(requestId), address(raffle));

        assert((raffle.getRecentWinner()) != address(0));
        assertEq(uint256(raffle.getRaffleState()), 0);
        assertEq(raffle.getNumberOfPlayers(), 0);
        console.log(raffle.getLastTimeStamp());
        console.log(startingTimeStamp);
        assert(raffle.getLastTimeStamp() > startingTimeStamp);
        assert(
            (raffle.getRecentWinner()).balance
                == (STARTING_BALANCE - ENOUGH_ETH_SENT) + (ENOUGH_ETH_SENT * playersAmount)
        );
    }

    /////////////////////////////
    // getter functions TEST ////
    /////////////////////////////
    /**
     * @dev some getter functions are tested in constructor tests
     */
    function testGetRaffleState() public raffleEnteredAndTimeIncreased {
        assertEq(uint256(raffle.getRaffleState()), 0);
        raffle.performUpkeep("");
        assertEq(uint256(raffle.getRaffleState()), 1);
    }

    function testGetNumWords() public {
        assertEq(raffle.getNumWords(), 1);
    }

    function testGetRequestConfirmations() public {
        assertEq(raffle.getRequestConfirmations(), 3);
    }

    function testGetPlayer() public {
        vm.prank(USER);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        vm.prank(USER2);
        raffle.enterRaffle{value: ENOUGH_ETH_SENT}();
        assertEq(raffle.getPlayer(0), USER);
        assertEq(raffle.getPlayer(1), USER2);
    }

    function testGetLastTimeStamp() public view {
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
