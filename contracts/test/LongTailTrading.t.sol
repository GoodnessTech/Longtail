// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { LongTailMarketFactory } from "../src/factory/LongTailMarketFactory.sol";
import { ILongTailMarketFactory } from "../src/factory/ILongTailMarketFactory.sol";
import { LongTailMarket } from "../src/market/LongTailMarket.sol";
import { ILongTailMarket } from "../src/market/ILongTailMarket.sol";
import { LongTailOutcomeToken } from "../src/market/LongTailOutcomeToken.sol";
import { LMSRPricingModel } from "../src/pricing/LMSRPricingModel.sol";
import { OptimisticResolver } from "../src/resolution/OptimisticResolver.sol";
import { Errors } from "../src/libraries/Errors.sol";

contract LongTailTradingTest is Test {
    LongTailMarketFactory public factory;
    LongTailMarket public implementation;
    LongTailOutcomeToken public outcomeToken;
    LMSRPricingModel public pricingModel;
    OptimisticResolver public resolver;
    ILongTailMarket public market;

    address public owner = address(this);
    address public creator = address(0xAA11);
    address public alice = address(0xBB11);
    address public bob = address(0xCC22);

    uint256 public marketId;
    uint256 public initialSeed = 5 ether;

    function setUp() public {
        vm.deal(creator, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        implementation = new LongTailMarket();
        outcomeToken = new LongTailOutcomeToken("https://api.longtail.io/token/{id}.json");
        pricingModel = new LMSRPricingModel();
        resolver = new OptimisticResolver(owner);

        factory = new LongTailMarketFactory(
            address(implementation),
            address(outcomeToken),
            address(resolver),
            address(pricingModel),
            owner
        );

        outcomeToken.setFactory(address(factory));
        resolver.setFactory(address(factory));

        // Create market with 1% fee
        vm.startPrank(creator);
        ILongTailMarketFactory.CreateMarketParams memory params = ILongTailMarketFactory.CreateMarketParams({
            question: "Will OpenAI release a flagship model before July?",
            metadataURI: "ipfs://QmAITest",
            category: "AI",
            closingTimestamp: uint64(block.timestamp + 15 days),
            resolutionDeadline: uint64(block.timestamp + 20 days),
            resolver: address(resolver),
            pricingModel: address(pricingModel),
            b: initialSeed,
            feeBps: 100 // 1%
        });

        address marketAddr;
        (marketId, marketAddr) = factory.createMarket{ value: initialSeed }(params);
        market = ILongTailMarket(marketAddr);
        vm.stopPrank();
    }

    function test_InitialProbabilityIs50Percent() public view {
        uint256 pYes = market.getProbability();
        assertEq(pYes, 5e17); // 50%
    }

    function test_BuyYESIncreasesProbabilityAndIssuesTokens() public {
        vm.startPrank(alice);
        uint256 buyAmount = 1 ether;
        (uint256 expectedShares, uint256 fee) = market.getSharesForCost(true, buyAmount);
        assertTrue(expectedShares > 0);
        assertEq(fee, (buyAmount * 100) / 10000); // 1% fee = 0.01 ether

        uint256 sharesBought = market.buy{ value: buyAmount }(true, expectedShares);
        vm.stopPrank();

        assertEq(sharesBought, expectedShares);

        // Verify ERC-1155 token balance
        uint256 yesTokenId = outcomeToken.getTokenId(marketId, true);
        assertEq(outcomeToken.balanceOf(alice, yesTokenId), sharesBought);

        // Probability of YES should now be strictly greater than 50%
        uint256 newProb = market.getProbability();
        assertTrue(newProb > 5e17);

        // Market state verification
        ILongTailMarket.MarketState memory st = market.getState();
        assertEq(st.qYes, sharesBought);
        assertEq(st.qNo, 0);
        assertEq(st.collateralBalance, initialSeed + buyAmount - fee);
    }

    function test_BuyNOIncreasesNOProbability() public {
        vm.startPrank(bob);
        uint256 buyAmount = 2 ether;
        (uint256 expectedShares, ) = market.getSharesForCost(false, buyAmount);

        uint256 sharesBought = market.buy{ value: buyAmount }(false, expectedShares);
        vm.stopPrank();

        // Verify ERC-1155 NO token balance
        uint256 noTokenId = outcomeToken.getTokenId(marketId, false);
        assertEq(outcomeToken.balanceOf(bob, noTokenId), sharesBought);

        // Probability of YES should now be strictly less than 50%
        uint256 newProb = market.getProbability();
        assertTrue(newProb < 5e17);
    }

    function test_RevertWhen_SlippageExceeded() public {
        vm.startPrank(alice);
        uint256 buyAmount = 1 ether;
        (uint256 expectedShares, ) = market.getSharesForCost(true, buyAmount);

        // Ask for 10% more shares than quote provides
        vm.expectRevert(Errors.SlippageExceeded.selector);
        market.buy{ value: buyAmount }(true, expectedShares + 1 ether);
        vm.stopPrank();
    }

    function test_SellYESReducesPositionAndReturnsBOT() public {
        // Alice buys YES
        vm.startPrank(alice);
        uint256 buyAmount = 2 ether;
        uint256 shares = market.buy{ value: buyAmount }(true, 1);
        uint256 balBefore = alice.balance;

        // Alice sells half her shares
        uint256 sellShares = shares / 2;
        (uint256 expectedProceeds, ) = market.getQuote(true, sellShares, false);
        assertTrue(expectedProceeds > 0);

        uint256 proceeds = market.sell(true, sellShares, expectedProceeds);
        vm.stopPrank();

        assertEq(proceeds, expectedProceeds);
        assertEq(alice.balance, balBefore + proceeds);

        // Token balance decreased by sellShares
        uint256 yesTokenId = outcomeToken.getTokenId(marketId, true);
        assertEq(outcomeToken.balanceOf(alice, yesTokenId), shares - sellShares);
    }

    function test_RevertWhen_SellingMoreThanOwned() public {
        vm.startPrank(alice);
        market.buy{ value: 1 ether }(true, 1);

        // Alice tries to sell NO shares she does not own
        vm.expectRevert(Errors.InsufficientBalance.selector);
        market.sell(false, 1 ether, 0);
        vm.stopPrank();
    }

    function test_RevertWhen_TradingAfterMarketCloses() public {
        // Fast-forward past closing timestamp (15 days)
        vm.warp(block.timestamp + 16 days);

        vm.startPrank(alice);
        vm.expectRevert(Errors.TradingPeriodEnded.selector);
        market.buy{ value: 1 ether }(true, 0);
        vm.stopPrank();
    }

    function test_ProtocolFeeAccumulation() public {
        uint256 factoryFeesBefore = address(factory).balance;

        vm.startPrank(alice);
        uint256 tradeAmount = 10 ether;
        market.buy{ value: tradeAmount }(true, 0);
        vm.stopPrank();

        uint256 expectedFee = (tradeAmount * 100) / 10000; // 1% = 0.1 ether
        assertEq(address(factory).balance, factoryFeesBefore + expectedFee);
    }
}
