// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract Crowdsale is Ownable, ReentrancyGuard {
    // The token being sold
    ERC20 public token;

    // Address where funds are collected
    address payable public wallet;

    AggregatorV3Interface internal priceFeed;

    // Amount of wei raised
    uint256 public weiRaised;

    uint8 public decimals;

    uint256 private tokenPrice;

    event TokensPurchasedWithNativeCurrency(
        address indexed buyer,
        uint256 amount
    );
    event TokensPurchasedWithNativeStableCoin(
        address indexed buyer,
        uint256 amount,
        address tokenAddress
    );

    constructor(
        address payable _wallet,
        ERC20 _token,
        address _aggregatorAddress,
        uint256 _initialTokenPrice
    ) {
        require(_initialTokenPrice > 0);
        require(_wallet != address(0));

        wallet = _wallet;
        token = _token;
        priceFeed = AggregatorV3Interface(_aggregatorAddress);
        weiRaised = 0;
        tokenPrice = _initialTokenPrice; // $0.02
    }

    fallback() external payable {
        buyTokensWithNativeCurrency();
    }

    receive() external payable {
        buyTokensWithNativeCurrency();
    }

    function buyTokensWithNativeCurrency() public payable nonReentrant {
        uint256 tokensToSendInEther = getTokensAmountForNativeCurrency(
            msg.value
        );
        weiRaised += msg.value;

        require(
            token.allowance(owner(), address(this)) >= tokensToSendInEther,
            "Contract not approved to spend tokens"
        );

        require(
            token.transferFrom(owner(), msg.sender, tokensToSendInEther),
            "Token transfer failed"
        );
        emit TokensPurchasedWithNativeCurrency(msg.sender, tokensToSendInEther);
    }

    function getTokensAmountForNativeCurrency(
        uint256 nativeCurrencyValue
    ) public view returns (uint256) {
        (, int256 latestPrice, , , ) = priceFeed.latestRoundData();

        uint256 latestPriceInWei = uint256(latestPrice) * 1e10;
        uint256 value = latestPriceInWei * nativeCurrencyValue;

        uint256 tokensToSend = value / tokenPrice;
        uint256 tokensToSendInEther = tokensToSend / 1e18;
        return tokensToSendInEther;
    }

    // @param usdtAmount - amount of usdt in wei to be send
    // approve outside, contact can spend on behalf of the user the
    function buyTokensWithStableCoin(
        uint256 usdtAmount,
        address stableCoinAddress
    ) public nonReentrant {
        require(usdtAmount >= 1e6, "Minimum buy amount not satisfied");

        IERC20 stableCoin = IERC20(stableCoinAddress);

        // Ensure that the contract has been approved to spend USDT tokens on behalf of the sender
        require(
            stableCoin.allowance(msg.sender, address(this)) >= usdtAmount,
            "Contract not approved to spend tokens"
        );

        require(
            stableCoin.transferFrom(msg.sender, owner(), usdtAmount),
            "USDT transfer failed"
        );

        uint256 tokensToSend = getTokensAmountForStableCoin(usdtAmount);

        require(
            token.transferFrom(owner(), msg.sender, tokensToSend),
            "FLI Token transfer failed"
        );
        emit TokensPurchasedWithNativeStableCoin(
            msg.sender,
            tokensToSend,
            stableCoinAddress
        );
    }

    function getTokensAmountForStableCoin(
        uint256 _paymentAmount
    ) public view returns (uint256) {
        return (_paymentAmount * 1e12) / tokenPrice;
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

    function getTokenPrice() public view returns (uint256) {
        return tokenPrice;
    }

    function changeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        transferOwnership(newOwner);
    }
}
