// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title A sample raffling contract
 * @author Akshat
 * @notice This is a sample raffling contract
 * @dev Implements Chainlink VRFv2
 */
    
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import {console} from "forge-std/Script.sol";

contract Raffle is VRFConsumerBaseV2,AutomationCompatibleInterface
{
    //errors

    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance , uint256 numPlayers , uint256 raffleState );

    // type declarations
    enum RaffleState { OPEN , CALCULATING} 

    // state variables

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // events

    event enteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event WinnerRequested(uint256 indexed reqId);

    constructor(uint256 entranceFee , uint256 interval , address vrfCoordinator , bytes32 gasLane , uint64 subscriptionId , uint32 callbackGasLimit) VRFConsumerBaseV2(vrfCoordinator)
    {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable
    {
        if(msg.value < i_entranceFee)
        {
            revert Raffle__NotEnoughEthSent();
        }
        if(s_raffleState != RaffleState.OPEN)
        {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit enteredRaffle(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `checkUpkeep` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. The contract has players
     * 5. Implicity, your subscription is funded with LINK.
     */

    function checkUpkeep (bytes memory /* checkdata */) public view returns(bool upkeepNeeded , bytes memory /* performData */)
    {
        bool timePassed = (block.timestamp - s_lastTimestamp) >= i_interval ;
        bool isOpen = (s_raffleState == RaffleState.OPEN) ;
        bool hasBalance = address(this).balance >= 0 ;
        bool hasPlayers = s_players.length >0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded , "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external override
    {
        (bool upkeepNeeded , ) = checkUpkeep("");
        if(!upkeepNeeded)
        {
            revert Raffle__UpkeepNotNeeded(address(this).balance , s_players.length , uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        console.log("msg.sender " , msg.sender);
        console.log("subId" , i_subscriptionId);
        
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit WinnerRequested(requestId);
    }
    // CEI : checks , effects , interactions
    function fulfillRandomWords(uint256 /*requestId*/ , uint256[] memory randomWords) internal override
    {
        // checks - require / if-else statements
        // effects(our contract)
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_recentWinner = winner ;
        s_raffleState = RaffleState.OPEN ;
        s_players = new address payable[](0) ;
        s_lastTimestamp = block.timestamp ;
        emit PickedWinner(winner); // put events before interactions
        // interactions(other contracts)
        (bool success,) = winner.call{value : address(this).balance}("");
        if(!success)
        {
            revert Raffle__TransferFailed();
        }
    }

    // Getter functions

    function getEntranceFee() external view returns(uint256)
    {
        return i_entranceFee;
    }
    function getRaffleState() external view returns(RaffleState)
    {
        return s_raffleState;
    }
    function getPlayer(uint256 index) external view returns(address)
    {
        return s_players[index];
    }
    function getRecentWinner() external view returns(address)
    {
        return s_recentWinner;
    }
    function getNumberOfPlayers() external view returns(uint256)
    {
        return s_players.length;
    }
    function getLastTimestamp() external view returns(uint256)
    {
        return s_lastTimestamp;
    }
}
// option + arrow keys to move whole lines without selecting