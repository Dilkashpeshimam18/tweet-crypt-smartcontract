// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TweetCrypt is ReentrancyGuard, Ownable {
    // Enum to define prediction types
    enum Prediction {
        None,
        High,
        Low
    }

    // Structure to track each user's bet
    struct Bet {
        Prediction prediction;
        uint256 amount;
    }

    // Structure to track each tweet's investment pool
    struct TweetContract {
        uint256 tweetId;
        uint256 totalHighBets;
        uint256 totalLowBets;
        uint256 startTime;
        bool resolved;
        Prediction result;
        mapping(address => Bet) userBets; // Users' bets
    }

    // Store each tweet contract using tweetId
    mapping(uint256 => TweetContract) public tweetContracts;

    // Events to log predictions and results
    event BetPlaced(
        uint256 tweetId,
        address indexed user,
        Prediction prediction,
        uint256 amount
    );
    event TweetResolved(uint256 tweetId, Prediction result);
    event RewardsClaimed(address indexed user, uint256 amount);

    // Modifier to ensure the tweet is not yet resolved
    modifier tweetNotResolved(uint256 tweetId) {
        require(!tweetContracts[tweetId].resolved, "Tweet already resolved.");
        _;
    }

    // Modifier to ensure the tweet is resolved
    modifier tweetIsResolved(uint256 tweetId) {
        require(tweetContracts[tweetId].resolved, "Tweet is not yet resolved.");
        _;
    }

    constructor() payable Ownable(msg.sender) {}

    // Function to place a bet on a tweet's virality (either High or Low)
    function placeBet(uint256 tweetId, Prediction prediction)
        external
        payable
        tweetNotResolved(tweetId)
        nonReentrant
    {
        require(
            prediction == Prediction.High || prediction == Prediction.Low,
            "Invalid prediction."
        );
        require(msg.value > 0, "Bet amount must be greater than zero.");

        TweetContract storage tweet = tweetContracts[tweetId];
        Bet storage userBet = tweet.userBets[msg.sender];

        require(
            userBet.amount == 0,
            "You have already placed a bet on this tweet."
        );

        // Register user's bet
        userBet.prediction = prediction;
        userBet.amount = msg.value;

        if (prediction == Prediction.High) {
            tweet.totalHighBets += msg.value;
        } else if (prediction == Prediction.Low) {
            tweet.totalLowBets += msg.value;
        }

        emit BetPlaced(tweetId, msg.sender, prediction, msg.value);
    }

    // Function to resolve a tweet after the virality prediction is known
    function resolveTweet(uint256 tweetId, Prediction actualResult)
        external
        onlyOwner
        tweetNotResolved(tweetId)
    {
        require(
            actualResult == Prediction.High || actualResult == Prediction.Low,
            "Invalid result."
        );

        TweetContract storage tweet = tweetContracts[tweetId];
        tweet.resolved = true;
        tweet.result = actualResult;

        emit TweetResolved(tweetId, actualResult);
    }

    // Function to claim rewards after a tweet is resolved
    function claimReward(uint256 tweetId)
        external
        tweetIsResolved(tweetId)
        nonReentrant
    {
        TweetContract storage tweet = tweetContracts[tweetId];
        Bet storage userBet = tweet.userBets[msg.sender];

        require(userBet.amount > 0, "You have not placed any bets.");
        require(
            userBet.prediction == tweet.result,
            "Your prediction was incorrect."
        );

        uint256 reward = calculateReward(tweetId, msg.sender);
        userBet.amount = 0; // Prevent re-entrancy

        payable(msg.sender).transfer(reward);

        emit RewardsClaimed(msg.sender, reward);
    }

    // Internal function to calculate the reward for a correct prediction
    function calculateReward(uint256 tweetId, address user)
        internal
        view
        returns (uint256)
    {
        TweetContract storage tweet = tweetContracts[tweetId];
        Bet storage userBet = tweet.userBets[user];

        uint256 rewardPool = tweet.result == Prediction.High
            ? tweet.totalHighBets
            : tweet.totalLowBets;
        uint256 oppositePool = tweet.result == Prediction.High
            ? tweet.totalLowBets
            : tweet.totalHighBets;

        // Calculate user's reward proportionally to their bet
        uint256 reward = userBet.amount +
            (userBet.amount * oppositePool) /
            rewardPool;

        return reward;
    }

    // Function to create a new tweet contract
    function createTweetContract(uint256 tweetId) external onlyOwner {
        TweetContract storage tweet = tweetContracts[tweetId];
        require(tweet.startTime == 0, "Tweet contract already exists.");

        tweet.tweetId = tweetId;
        tweet.startTime = block.timestamp;
    }

    // Function to withdraw contract balance by the owner
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Fallback and receive functions
    receive() external payable {}

    fallback() external payable {}
}
