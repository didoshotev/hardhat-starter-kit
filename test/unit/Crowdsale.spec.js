const { network, ethers } = require("hardhat")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")
const { assert, expect } = require("chai");
const USDT_ABI = require('../../ABIs/usdt-abi.json')

const EXPECTED_TOKEN_AMOUNT = 20000;
const TOKEN_APPROVAL_AMOUNT = 20000000000;

const USDT_BNC_ADDRESS = "0x55d398326f99059fF775485246999027B3197955"
const USDT_BNC_WHALE = "0x970609bA2C160a1b491b90867681918BDc9773aF"

// Define an array of objects containing different values for BNB payload and price
const payloadsAndPrices = [
  // { bnbPayloadInEther: 5, price: 0.0218 },
  // { bnbPayloadInEther: 3, price: 0.015 },
  // { bnbPayloadInEther: 2.5, price: 0.01 },
  { bnbPayloadInEther: 15.5, price: 0.02 },
  { bnbPayloadInEther: 0.005, price: 0.02 },
  // Add more objects as needed
];

const usdtPayloadsAndPrices = [
  { usdtPayloadInEther: 5, price: 0.02 },
  { usdtPayloadInEther: 44, price: 0.0238 },
  { usdtPayloadInEther: 21, price: 0.025 },
  { usdtPayloadInEther: 245012, price: 0.025 },
  // Add more objects as needed
];


!developmentChains.includes(network.name)
  ? describe.skip
  : describe.only("Crowdsale BNB Unit Tests", async function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployPriceConsumerFixture() {
      const [deployer, user1] = await ethers.getSigners()

      // TODO: fix this
      const FLITokenFactory = await ethers.getContractFactory("FreeLoveCoin")
      const FLIToken = await FLITokenFactory
        .connect(deployer)
        .deploy()


      const initialPrice = ethers.utils.parseUnits("0.02", 18)
      const RawCrowdsaleFactory = await ethers.getContractFactory("Crowdsale")
      const rawCrowdsale = await RawCrowdsaleFactory
        .connect(deployer)
        .deploy(deployer.address, FLIToken.address, networkConfig[56].ethUsdPriceFeed, initialPrice) // must be BNB/USD

      // Send ERC-20 tokens to the Crowdsale contract
      await FLIToken.transfer(rawCrowdsale.address, EXPECTED_TOKEN_AMOUNT);

      // Approve the contract to spend tokens on behalf of the owner
      await FLIToken.connect(deployer).approve(rawCrowdsale.address, TOKEN_APPROVAL_AMOUNT);

      return { rawCrowdsale, FLIToken, deployer, user1 }
    }

    describe("deployment", async function () {
      describe("success", async function () {
        it("should set the aggregator addresses correctly", async () => {
          const { FLIToken, rawCrowdsale } = await loadFixture(
            deployPriceConsumerFixture
          )
        })
      })
    });

    describe("should increase weiRaised when Ether is sent to the contract", async () => {
      const { rawCrowdsale, deployer, user1, FLIToken } = await loadFixture(deployPriceConsumerFixture);
      const initialBalance = await ethers.provider.getBalance(deployer.address);

      // Send some BNB to the contract
      const valueInBNB = ethers.utils.parseUnits("0.5", "ether"); // Sending 0.5 BNB

      // await rawCrowdsale.sendTransaction({ value: valueInBNB });
      const weiRaisedBefore = await rawCrowdsale.weiRaised();

      await user1.sendTransaction({ to: rawCrowdsale.address, value: valueInBNB })

      await rawCrowdsale.callStatic.buyTokensWithNativeCurrency(); // Call buyTokensWithNativeCurrency statically to inspect its state changes
      const weiRaisedAfter = await rawCrowdsale.weiRaised();

      assert.equal(
        weiRaisedAfter.sub(weiRaisedBefore).toString(),
        valueInBNB.toString(),
        "weiRaised should increase after sending Ether to the contract"
      );
    });

    describe("should allow the owner to withdraw native currency", async () => {
      const { rawCrowdsale, deployer, user1 } = await loadFixture(deployPriceConsumerFixture);

      // Record the initial balances
      const initialContractBalance = await ethers.provider.getBalance(rawCrowdsale.address);
      const initialOwnerBalance = await ethers.provider.getBalance(deployer.address);

      // Send some BNB to the contract
      const valueInBNB = ethers.utils.parseEther("0.5");
      await user1.sendTransaction({ to: rawCrowdsale.address, value: valueInBNB })

      // Check the contract's balance before withdrawal
      const contractBalanceBefore = await ethers.provider.getBalance(rawCrowdsale.address);

      // Withdraw BNB from the contract
      await rawCrowdsale.withdrawNativeCurrency();

      // Check the contract's balance after withdrawal
      const contractBalanceAfter = await ethers.provider.getBalance(rawCrowdsale.address);

      // Check the owner's balance after withdrawal
      const ownerBalanceAfter = await ethers.provider.getBalance(deployer.address);

      // Calculate the expected owner balance with tolerance
      const expectedOwnerBalance = initialOwnerBalance.add(valueInBNB);
      const tolerance = ethers.utils.parseEther("0.00005"); // 0.1 ETH tolerance

      // Contract balance should be reduced after withdrawal
      assert.equal(contractBalanceAfter.toString(), "0", "Contract balance should be zero after withdrawal");

      // Owner's balance should increase by the amount withdrawn
      assert(
        ownerBalanceAfter.sub(initialOwnerBalance).gte(valueInBNB.sub(tolerance)) &&
        ownerBalanceAfter.sub(initialOwnerBalance).lte(valueInBNB.add(tolerance)),
        "Owner's balance should increase by the amount withdrawn within tolerance"
      );
    });

    describe("divider helper function", async function () {
      it('should divide correctly', async () => {
        const { rawCrowdsale } = await loadFixture(deployPriceConsumerFixture);
        const result = await rawCrowdsale.divider(100, 25, 1)
        assert.equal(result, 40)
      })
    })

    describe("buyTokensWithStableCoin VERSION 2", async function () {
      // it('DEFAULT 0.02', async function () {
      //   const { rawCrowdsale, deployer, user1, FLIToken } = await loadFixture(deployPriceConsumerFixture);
      //   const usdtPayloadInEther = 1;
      //   const price = 0.02;
      //   await rawCrowdsale.changeTokenPrice(ethers.utils.parseUnits(price.toString(), 18));

      //   const USDT_BUY_AMOUNT = ethers.utils.parseUnits(usdtPayloadInEther.toString(), 6)

      //   await setupTest(rawCrowdsale, user1, USDT_BUY_AMOUNT)

      //   let usdtContract = new ethers.Contract(USDT_BNC_ADDRESS, USDT_ABI, deployer);

      //   await rawCrowdsale.connect(user1).buyTokensWithStableCoin(USDT_BUY_AMOUNT, USDT_BNC_ADDRESS)

      //   const deployerUSDTBalanceAfter = await usdtContract.balanceOf(deployer.address);
      //   const deployerUSDTBalanceAfterFormatted = ethers.utils.formatUnits(deployerUSDTBalanceAfter.toString(), 6);
      //   const user1FLIBalanceAfter = await FLIToken.balanceOf(user1.address);

      //   const expectedResult = usdtPayloadInEther / price;

      //   assert.equal(user1FLIBalanceAfter, Math.floor(expectedResult))
      //   assert.equal(deployerUSDTBalanceAfterFormatted, usdtPayloadInEther)
      // })

      for (const { usdtPayloadInEther, price } of usdtPayloadsAndPrices) {
        it(`CURRENT PRICE: ${price}`, async function () {
          const { rawCrowdsale, deployer, user1, FLIToken } = await loadFixture(deployPriceConsumerFixture);
          const USDT_BUY_AMOUNT = ethers.utils.parseUnits(usdtPayloadInEther.toString(), 6);

          await rawCrowdsale.changeTokenPrice(ethers.utils.parseUnits(price.toString(), 18));

          await setupTest(rawCrowdsale, user1, USDT_BUY_AMOUNT);

          let usdtContract = new ethers.Contract(USDT_BNC_ADDRESS, USDT_ABI, deployer);

          await rawCrowdsale.connect(user1).buyTokensWithStableCoin(USDT_BUY_AMOUNT, USDT_BNC_ADDRESS);

          const deployerUSDTBalanceAfter = await usdtContract.balanceOf(deployer.address);
          const user1FLIBalanceAfter = await FLIToken.balanceOf(user1.address);

          const expectedResult = usdtPayloadInEther / price;

          assert.equal(user1FLIBalanceAfter, Math.floor(expectedResult))
          assert.equal(ethers.utils.formatUnits(deployerUSDTBalanceAfter.toString(), 6), usdtPayloadInEther)
        });
      }
    })

    describe("buyTokensWithNativeCurrency VERSION 2", async function () {
      it.skip('DEFAULT 0.02', async function () {
        const bnbPayloadInEther = 1
        const price = 0.02;

        const { rawCrowdsale, deployer, user1, FLIToken } = await loadFixture(deployPriceConsumerFixture);

        const BNB_BUY_AMOUNT = ethers.utils.parseUnits(bnbPayloadInEther.toString(), 18)
        const currentBNBPrice = await rawCrowdsale.getLatestPriceOfBNB()
        const currentBNBPriceInDollars = ethers.utils.formatUnits(currentBNBPrice, 8)

        // Record balances before the purchase
        const deployerFLIBalanceBefore = await FLIToken.balanceOf(deployer.address);
        const user1FLIBalanceBefore = await FLIToken.balanceOf(user1.address);

        await rawCrowdsale.connect(deployer).changeTokenRate(2000)
        await rawCrowdsale.connect(user1).buyTokensWithNativeCurrency({ value: BNB_BUY_AMOUNT });

        // Record balances after the purchase
        const deployerFLIBalanceAfter = await FLIToken.balanceOf(deployer.address);
        const user1FLIBalanceAfter = await FLIToken.balanceOf(user1.address);

        const value = currentBNBPriceInDollars * bnbPayloadInEther;
        const tokensToSend = value / price

        // Assert that balances have changed appropriately
        assert.isAbove(deployerFLIBalanceBefore, deployerFLIBalanceAfter);
        assert.isAbove(user1FLIBalanceAfter, user1FLIBalanceBefore);
        assert.equal(Math.floor(tokensToSend), user1FLIBalanceAfter)
      })
      for (const { bnbPayloadInEther, price } of payloadsAndPrices) {
        it(`${price}`, async function () {
          const { rawCrowdsale, deployer, user1, FLIToken } = await loadFixture(deployPriceConsumerFixture);

          const BNB_BUY_AMOUNT = ethers.utils.parseUnits(bnbPayloadInEther.toString(), 18);
          const currentBNBPrice = await rawCrowdsale.getLatestPriceOfBNB();
          const currentBNBPriceInDollars = ethers.utils.formatUnits(currentBNBPrice, 8);

          await rawCrowdsale.changeTokenPrice(ethers.utils.parseUnits(price.toString(), 18));
          await rawCrowdsale.connect(user1).buyTokensWithNativeCurrency({ value: BNB_BUY_AMOUNT });

          const user1FLIBalanceAfter = await FLIToken.balanceOf(user1.address);

          const value = currentBNBPriceInDollars * bnbPayloadInEther;
          const tokensToSend = value / price;

          assert.equal(Math.floor(tokensToSend), parseInt(user1FLIBalanceAfter.toString()));
        });
      }
    })
  })


async function setupTest(rawCrowdsale, user1, USDT_BUY_AMOUNT) {
  // impresonate USDT
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [USDT_BNC_WHALE],
  });
  const whaleSigner = await ethers.getSigner(USDT_BNC_WHALE);

  let usdtContract = new ethers.Contract(USDT_BNC_ADDRESS, USDT_ABI, whaleSigner);

  // Transfer tokens to user1 from whale
  const transferTx = await usdtContract.transfer(user1.address, USDT_BUY_AMOUNT);
  await transferTx.wait();

  // APPROVAL
  usdtContract = new ethers.Contract(USDT_BNC_ADDRESS, USDT_ABI, user1);
  await usdtContract.approve(rawCrowdsale.address, USDT_BUY_AMOUNT);
}