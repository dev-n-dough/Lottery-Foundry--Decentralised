// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Raffle} from "../src/Raffle.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol"; 
import {DeployRaffle} from "./DeployRaffle.s.sol";


contract CreateSubscription is Script
{
    function createSubscriptionUsingConfig() public returns(uint64)
    {
        HelperConfig helper = new HelperConfig();
        (,,address vrfCoordinator,,,,) = helper.activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns(uint64)
    {
        console.log("Creating subscription on ChainID : ", block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        // consozle.log("Owner of subscription :" , msg.sender);
        // console.log("Address of this contract :" , address(this));
        // console.log("Address of vrfCoordinator" , vrfCoordinator);
        console.log("Your sub ID is ",subId);
        return subId;
    }

    function run() external returns(uint64)
    {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script
{
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public
    {
        HelperConfig helper = new HelperConfig();
        (,,address vrfCoordinator,,uint64 subId,,address link) = helper.activeNetworkConfig();
        fundSubscription(vrfCoordinator,subId,link);
    }

    function fundSubscription(address vrfCoordinator , uint64 subId , address link) public
    {
        console.log("Funding subscription :" , subId);
        console.log("Using vrfCoordinator :", vrfCoordinator);
        console.log("On chainID ", block.chainid);
        if(block.chainid == 31337)
        {
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId,FUND_AMOUNT);
            vm.stopBroadcast();
        }
        else
        {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT , abi.encode(subId));
            vm.stopBroadcast();
        }
        console.log("Funding Successful of subId ",subId);
    }

    function run() external
    {
        //console.log(msg.sender);
        fundSubscriptionUsingConfig();
    }
}

// add raffle as a consumer of our subscription
contract AddConsumer is Script
{
    function addConsumer(address raffle , address vrfCoordinator , uint64 subId) public
    {
        // console.log("Adding consumer contract ", raffle);
        // console.log("Using VRFCoordinator ", vrfCoordinator);
        console.log("On chain " , block.chainid);
        // console.log("msg.sender" , msg.sender);
        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }


    function addConsumerUsingConfig(address raffle) public
    { 
        HelperConfig helper = new HelperConfig();
        (,,address vrfCoordinator,,uint64 subId,,) = helper.activeNetworkConfig();
        addConsumer(raffle ,  vrfCoordinator, subId);

    }
    function run() external
    {
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        //address raffle = 0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3;
        // address raffle = 0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3;
        addConsumerUsingConfig(raffle);
    }
}
// 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
// 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38