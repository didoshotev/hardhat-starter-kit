// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

    uint256 private tokenPrice;

    event TokensPurchased(address indexed buyer, uint256 amount);

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
        weiRaised = 0;
        tokenRate = 20;
        decimals = 1;
        tokenPrice = 2 * 1e16; // $0.02
    }

    fallback() external payable {
        console.log("FALLBACK activated...");
        // buyTokensWithNativeCurrency();
    }

    receive() external payable {
        console.log("RECEIVE activated...");
        // buyTokensWithNativeCurrency();
    }

    // TODO: fix
    function buyTokensWithNativeCurrency() public payable nonReentrant {
        (, int256 latestPrice, , , ) = priceFeed.latestRoundData();
        console.log("tokenPrice: ", tokenPrice);

        uint256 latestPriceInWei = uint256(latestPrice) * 1e10; // 10000000000
        uint256 value = (latestPriceInWei * msg.value);

        uint256 tokensToSend = value / tokenPrice;
        uint256 tokensToSendInEther = tokensToSend / 1e18;

        weiRaised += msg.value;

        // Ensure that the contract has been approved to spend tokens on behalf of the sender
        require(
            token.allowance(owner(), address(this)) >= tokensToSendInEther,
            "Contract not approved to spend tokens"
        );

        require(
            token.transferFrom(owner(), msg.sender, tokensToSendInEther),
            "Token transfer failed"
        );
        emit TokensPurchased(msg.sender, tokensToSendInEther);
    }

    // @param usdtAmount - amount of usdt in wei to be send
    // approve outside, contact can spend on behalf of the user the
    function buyTokensWithStableCoin(
        uint256 usdtAmount,
        address stableCoinAddress
    ) public nonReentrant {
        require(usdtAmount >= 1e6, "Minimum buy amount not satisfied");

        IERC20 stableCoin = IERC20(stableCoinAddress);
        uint256 currAllowance = stableCoin.allowance(msg.sender, address(this));

        // Ensure that the contract has been approved to spend USDT tokens on behalf of the sender
        require(
            stableCoin.allowance(msg.sender, address(this)) >= usdtAmount,
            "Contract not approved to spend tokens"
        );

        // Transfer USDT tokens from the sender to this contract
        require(
            stableCoin.transferFrom(msg.sender, owner(), usdtAmount),
            "USDT transfer failed"
        );
        console.log("usdtAmount: ", usdtAmount);

        // TODO: test if you change the value and that still works
        uint256 numberOfTokens = getTokensAmountForStableCoin(usdtAmount);

        uint256 tokensFLIFormatted = numberOfTokens / 1e6;

        console.log("We must give: ", numberOfTokens, "FLI");
        console.log("Formatted FLI: ", tokensFLIFormatted);

        // uint256 tokenAmountInWei = (
        //     divider(valueOfBNBInWei, tokenRate, decimals)
        // ) * 100;
        // uint256 numberOfFLITokens = tokenAmountInEther / tokenPriceInUSDT;

        require(
            token.transferFrom(owner(), msg.sender, numberOfTokens),
            "FLI Token transfer failed"
        );

        // Calculate the equivalent token amount based on the USDT value
        console.log("success...!");
        // emit TokensPurchased(msg.sender, tokenAmountInEther);
    }

    function getTokensAmountForStableCoin(
        uint256 _paymentAmount
    ) public view returns (uint256) {
        uint256 currDecimals = 7;
        return
            (_paymentAmount * (10 ** uint256(currDecimals))) /
            (tokenRate * 10 ** 6);
    }

    function getTokensAmountForNativeCurrency(
        uint256 nativeCurrencyValue
    ) public view returns (uint256) {
        return (divider(nativeCurrencyValue, tokenRate, decimals)) * 100;
    }

    function getLatestPriceOfBNB() public view returns (int) {
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

    // in wei
    function changeTokenPrice(uint256 newPrice) external onlyOwner {
        tokenPrice = newPrice;
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
