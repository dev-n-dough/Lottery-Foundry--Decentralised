//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from  "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RaffleTest is Test
{

    event enteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    // IERC20 constant LINK_TOKEN = IERC20(0x779877A7B0D9E8603169DdbD7836e478b4624789);


    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entranceFee ;
    uint256 interval ;
    address vrfCoordinator ;
    bytes32 gasLane ;
    uint64 subscriptionId ; 
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() public
    {
        // console.log(msg.sender);
        // uint256 balance = LINK_TOKEN.balanceOf(msg.sender);
        // console.log("LINK balance of default account:", balance);


        // address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
        // uint256 allowance = LINK_TOKEN.allowance(msg.sender, vrfCoordinator);
        // console.log("LINK allowance for VRF Coordinator:", allowance);
        
        // uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        // vm.startBroadcast(/*deployerKey*/);
        
        DeployRaffle deployer = new DeployRaffle();
        (raffle,helperConfig) = deployer.run();
        (
            entranceFee ,
            interval ,
            vrfCoordinator ,
            gasLane ,
            subscriptionId , 
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER,STARTING_USER_BALANCE);
        // vm.startBroadcast();
    }


    function testRaffleInitialisesInOpenState() public view
    {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); // raffle.RaffleState is wrong 
        console.log(subscriptionId);
    } 

    function testRaffleRevertsWhenYouDontSendEnoughEth() public
    {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle(); // no money sent
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEmitsEventOnEnterance() public  ///// TESTING EVENT GETS EMITTED
    {
        vm.prank(PLAYER);
        vm.expectEmit(true, false,false,false, address(raffle));
        emit enteredRaffle(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
    }
    function testCantEnterWhenRaffleIsCalculating() public
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
    }

    // test Check Upkeep function 

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public
    {
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseWhenRaffleIsCalculating() public
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function  testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed()  public
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.roll(block.number +1);
        (bool  upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }
    function testCheckUpkeepReturnsTrueIfParamsAreGood() public
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool  upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }
    // performUpkeepTests

    function testPerformUpkeepRunsOnlyWhenCheckUpkeepReturnsTrue() public
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep(""); // if this runs without error,then test will pass

    }

    function testPerformUpkeepRevertsIfCheckUpkeepReturnsFalse() public
    {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.expectRevert();
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepReturnsFalseCUSTOMError() public
    {
        uint256 currentBalance = 0;
        uint256 numPlayers =0;
        uint256 raffleState=0;

        // we are expecting the following event with the following params
        vm.expectRevert(
            abi.encodeWithSelector(
            Raffle.Raffle__UpkeepNotNeeded.selector,
            currentBalance,
            numPlayers,
            raffleState
        )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed()
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepChangesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 reqId = logs[1].topics[1];

        Raffle.RaffleState state = raffle.getRaffleState();

        assert(uint256(reqId)>0);
        assert(uint256(state) == 1); // OR -> assert(uint256(state))
    }

    //  fulfillrandomwords test

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEnteredAndTimePassed
    {
        // all conditions for checkupKeep to be true are there,
        // but PerformUpkeep hasnt been called, so for any reqId, 
        // our raffle contract should not have any request
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId,address(raffle));
    }

    function testFulfillRandomWordsFULLTest() public raffleEnteredAndTimePassed
    {
        // add some players in the lottery
        uint256 startingIndex =1;
        uint256 additionalPlayers =7;
        for(uint256  i=startingIndex;i<startingIndex+additionalPlayers;i++)
        {
            address player = address(uint160(i));
            hoax(player,STARTING_USER_BALANCE);
            raffle.enterRaffle{value : entranceFee}();
        }

        uint256 prizeMoney = entranceFee*(1+additionalPlayers); 

        // get the requestId to pass into the fulfillRandomWords function
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 reqId = logs[1].topics[1];

        uint256 previousTimestamp = raffle.getLastTimestamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(reqId),address(raffle));
        
        // now fulfillRandomWords function has been executed fully, write assert now:

        assert(raffle.getRecentWinner()!=address(0)); // assert winner has been picked
        assert(uint256(raffle.getRaffleState()) == 0); // raffle is now open again
        assert(raffle.getNumberOfPlayers()==0); // players array gets reset
        assert(raffle.getLastTimestamp() > previousTimestamp); // lastTimestamp gets updated

        // prize won by winner will be = prizeMoney, but had spent 'entranceFee' to enter,
        // so earned prizeMoney-entranceFee

        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + (prizeMoney-entranceFee));
    }
}

// account caling the tests - 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38