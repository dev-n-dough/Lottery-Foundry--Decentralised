// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test
{

    event enteredRaffle(address indexed player);

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
    }

    function testRaffleInitialisesInOpenState() public view
    {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); // raffle.RaffleState is wrong somehow
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
        vm.prank(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
    }
}