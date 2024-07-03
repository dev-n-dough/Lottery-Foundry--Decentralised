//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script , console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {CreateSubscription , FundSubscription , AddConsumer} from "./Interactions.s.sol";

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract DeployRaffle is Script
{
    function run() external returns(Raffle , HelperConfig)
    {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee ,
            uint256 interval ,
            address vrfCoordinator ,
            bytes32 gasLane ,
            uint64 subscriptionId , 
            uint32 callbackGasLimit,
            address link
        ) = helperConfig.activeNetworkConfig();

        // IERC20 LINK_TOKEN = IERC20(link);
        // uint256 amount = 100 *1e18 ; // 100 LINK, or use type(uint256).max for unlimited approval
        // LINK_TOKEN.approve(vrfCoordinator, amount);

        if(subscriptionId == 0)
        {
            // we will have to create a subscription
            CreateSubscription createSub = new CreateSubscription();
            subscriptionId = createSub.createSubscription(vrfCoordinator);

            // fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator , subscriptionId , link);  
        }

        // uint256 privateKey = vm.envUint("PVT_KEY");
        vm.startBroadcast(/*privateKey*/);
        Raffle raffle = new Raffle(
            entranceFee ,
            interval ,
            vrfCoordinator ,
            gasLane ,
            subscriptionId , 
            callbackGasLimit
        );

        vm.stopBroadcast();
        // add raffle to our vrf subscription

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle) , vrfCoordinator , subscriptionId);
        // console.log("Address of raffle contract ", address(raffle));
        return (raffle,helperConfig);
    }

}