const { network, ethers } = require("hardhat")
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")
const { assert } = require("chai")

console.log('network.name: ', network.name);

!developmentChains.includes(network.name)
  ? describe.skip
  : describe.only("Price Consumer BNB Unit Tests", async function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployPriceConsumerFixture() {
      const [deployer] = await ethers.getSigners()

      const DECIMALS = "18"
      const INITIAL_PRICE = "200000000000000000000"

      const mockV3AggregatorFactory = await ethers.getContractFactory("MockV3Aggregator")
      const mockV3Aggregator = await mockV3AggregatorFactory
        .connect(deployer)
        .deploy(DECIMALS, INITIAL_PRICE)

      const priceConsumerV3Factory = await ethers.getContractFactory("PriceConsumerV3")
      const priceConsumerV3 = await priceConsumerV3Factory
        .connect(deployer)
        .deploy(mockV3Aggregator.address) // must be BNB/USD

      return { priceConsumerV3, mockV3Aggregator }
    }

    describe("deployment", async function () {
      describe("success", async function () {
        it("should set the aggregator addresses correctly", async () => {
          const { priceConsumerV3, mockV3Aggregator } = await loadFixture(
            deployPriceConsumerFixture
          )
          const response = await priceConsumerV3.getPriceFeedAddress()
          console.log('-----------RESPONSE-----------')
          console.log(response);
          assert.equal(response, mockV3Aggregator.address)
        })
      })
    })

    describe("#getLatestPrice", async function () {
      describe("success", async function () {
        it("should return the same value as the mock", async () => {
          const { priceConsumerV3, mockV3Aggregator } = await loadFixture(
            deployPriceConsumerFixture
          )
          const priceConsumerResult = await priceConsumerV3.getLatestPrice()
          const priceFeedResult = (await mockV3Aggregator.latestRoundData()).answer
          console.log('priceFeedResult: ', priceFeedResult);
          assert.equal(priceConsumerResult.toString(), priceFeedResult.toString())
        })
      })
    })

    describe("check LINK", async function () {
      it("should check if the contract exists", async () => {
        // const AggregatorBNBUSDAdrress = "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE";
        const AggregatorBNBUSDAdrress = networkConfig[56].ethUsdPriceFeed;
        console.log('AggregatorBNBUSDAdrress: ', AggregatorBNBUSDAdrress);

        try {
          const code = await ethers.provider.getCode(AggregatorBNBUSDAdrress);

          if (code === "0x") {
            console.log(`No contract found at address ${AggregatorBNBUSDAdrress}`);
          } else {
            console.log(`Contract found at address ${AggregatorBNBUSDAdrress}`);
          }
        } catch (error) {
          console.error("Error occurred while checking contract existence:", error);
          assert.fail("Error occurred while checking contract existence");
        }
      });
    })
  })
