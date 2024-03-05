// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract RawCrowdsale is Ownable, ReentrancyGuard {
    // The token being sold
    ERC20 public token;

    // Address where funds are collected
    address payable public wallet;

    AggregatorV3Interface internal priceFeed;

    // Amount of wei raised
    uint256 public weiRaised;

    uint256 public tokenRate; // private ?
    uint8 public decimals;

    constructor(
        uint256 _rate,
        address payable _wallet,
        ERC20 _token,
        address _aggregatorAddress
    ) {
        require(_rate > 0);
        require(_wallet != address(0));

        wallet = _wallet;
        token = _token;
        priceFeed = AggregatorV3Interface(_aggregatorAddress);
        // tokenRate = 2; // Assuming 1 token costs $0.02 (2 cents)
        weiRaised = 0;
        tokenRate = 20;
        decimals = 1;
    }

    fallback() external payable {
        buyTokensWithNativeCurrency();
    }

    receive() external payable {
        buyTokensWithNativeCurrency();
    }

    function buyTokensWithNativeCurrency() public payable nonReentrant {
        console.log("------------------------------------");
        console.log("START buyTokensWithNativeCurrency...");
        console.log("msg value: ", msg.value);
        console.log("msg value in ether: ", msg.value / 1e18);

        (, int256 latestPrice, , , ) = priceFeed.latestRoundData();

        // Convert the latest BNB price to a uint256 with 18 decimals
        uint256 latestPriceInWei = uint256(latestPrice) * 1e10; // Convert to 18 decimals
        uint256 latestPriceInEther = uint256(latestPrice) / 1e8;

        console.log("latestPriceInWei: ", latestPriceInWei);
        console.log("latestPriceInEther: ", latestPriceInEther);

        uint256 valueOfBNBInWei = msg.value * latestPriceInEther;
        console.log("valueOfBNBInWei: ", valueOfBNBInWei);

        // TODO: make this dynamic
        // uint256 tokenAmountInWei = (valueOfBNBInWei / 2.5) * 100;
        // uint256 tokenAmountInWei = (divider(valueOfBNBInWei, 25, 1)) * 100;
        uint256 tokenAmountInWei = (
            divider(valueOfBNBInWei, tokenRate, decimals)
        ) * 100;
        uint256 tokenAmountInEther = tokenAmountInWei / 1e18;
        console.log("tokenAmount: ", tokenAmountInWei);
        console.log("tokenAmountInEther: ", tokenAmountInEther);

        // Transfer tokens to buyer
        require(
            token.transfer(msg.sender, tokenAmountInEther),
            "Token transfer failed"
        );
    }

    function getTokenAmountInEther() internal view returns (uint256) {}

    function getLatestPrice() public view returns (int) {
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }

    function getPriceFeedAddress() public view returns (AggregatorV3Interface) {
        return priceFeed;
    }

    // Function to withdraw BNB from the contract (only owner can call this)
    function withdrawNativeCurrency() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // verify this works fine
    // Function to withdraw ERC-20 tokens from the contract (only owner can call this)
    function withdrawTokens(
        address tokenAddress,
        uint256 amount
    ) external onlyOwner {
        if (tokenAddress != address(token)) {
            ERC20 newToken = ERC20(tokenAddress);
            require(
                newToken.transfer(owner(), amount),
                "Token transfer failed"
            );
            return;
        } else {
            require(token.transfer(owner(), amount), "Token transfer failed");
        }
    }

    function changeTokenRate(uint256 newRate) external onlyOwner {
        tokenRate = newRate;
    }

    function changeDividerDecimals(uint8 newDecimals) external onlyOwner {
        decimals = newDecimals;
    }

    // Helper function
    function divider(
        uint numerator,
        uint denominator,
        uint precision
    ) public pure returns (uint) {
        return (numerator * (uint(10) ** uint(precision))) / denominator;
    }
}
