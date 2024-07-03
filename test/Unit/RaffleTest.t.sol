// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RaffleTest is Test
{

    event enteredRaffle(address indexed player);

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

    function testEmitsEventOnEnterance() public
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

    // lets test the Check Upkeep function now

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
}

// account caling the tests - 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38