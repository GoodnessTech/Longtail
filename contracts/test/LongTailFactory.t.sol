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

contract LongTailFactoryTest is Test {
    LongTailMarketFactory public factory;
    LongTailMarket public implementation;
    LongTailOutcomeToken public outcomeToken;
    LMSRPricingModel public pricingModel;
    OptimisticResolver public resolver;

    address public owner = address(this);
    address public creator = address(0xAA11);
    address public user = address(0xBB22);

    function setUp() public {
        vm.deal(creator, 100 ether);
        vm.deal(user, 100 ether);

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
    }

    function test_FactoryDeployment() public view {
        assertEq(factory.marketImplementation(), address(implementation));
        assertEq(factory.outcomeToken(), address(outcomeToken));
        assertEq(factory.defaultResolver(), address(resolver));
        assertEq(factory.defaultPricingModel(), address(pricingModel));
        assertEq(factory.feeRecipient(), owner);
        assertEq(factory.getMarketCount(), 0);
    }

    function test_CreateMarketSuccess() public {
        vm.startPrank(creator);
        ILongTailMarketFactory.CreateMarketParams memory params = ILongTailMarketFactory.CreateMarketParams({
            question: "Will Base process more than 1B transactions in 2025?",
            metadataURI: "ipfs://QmTest123",
            category: "Protocols",
            closingTimestamp: uint64(block.timestamp + 30 days),
            resolutionDeadline: uint64(block.timestamp + 35 days),
            resolver: address(0),
            pricingModel: address(0),
            b: 1 ether,
            feeBps: 100 // 1%
        });

        (uint256 marketId, address marketAddress) = factory.createMarket{ value: 1 ether }(params);
        vm.stopPrank();

        assertEq(marketId, 1);
        assertTrue(marketAddress != address(0));
        assertEq(factory.getMarketCount(), 1);
        assertEq(factory.getMarketAddress(1), marketAddress);

        ILongTailMarket market = ILongTailMarket(marketAddress);
        ILongTailMarket.MarketConfig memory cfg = market.getConfig();
        assertEq(cfg.creator, creator);
        assertEq(cfg.question, "Will Base process more than 1B transactions in 2025?");
        assertEq(cfg.feeBps, 100);

        ILongTailMarket.MarketState memory st = market.getState();
        assertEq(uint256(st.status), uint256(ILongTailMarket.MarketStatus.ACTIVE));
        assertEq(st.collateralBalance, 1 ether);
        assertEq(st.totalLpShares, 1 ether);
    }

    function test_RevertWhen_EmptyQuestion() public {
        vm.startPrank(creator);
        ILongTailMarketFactory.CreateMarketParams memory params = ILongTailMarketFactory.CreateMarketParams({
            question: "",
            metadataURI: "",
            category: "DeFi",
            closingTimestamp: uint64(block.timestamp + 10 days),
            resolutionDeadline: uint64(block.timestamp + 15 days),
            resolver: address(0),
            pricingModel: address(0),
            b: 1 ether,
            feeBps: 100
        });

        vm.expectRevert(Errors.InvalidQuestion.selector);
        factory.createMarket{ value: 1 ether }(params);
        vm.stopPrank();
    }

    function test_RevertWhen_InvalidTimestamps() public {
        vm.startPrank(creator);
        // Closing timestamp in the past
        ILongTailMarketFactory.CreateMarketParams memory p1 = ILongTailMarketFactory.CreateMarketParams({
            question: "Question 1",
            metadataURI: "",
            category: "DeFi",
            closingTimestamp: uint64(block.timestamp - 1),
            resolutionDeadline: uint64(block.timestamp + 10 days),
            resolver: address(0),
            pricingModel: address(0),
            b: 1 ether,
            feeBps: 100
        });
        vm.expectRevert(Errors.InvalidTimestamps.selector);
        factory.createMarket{ value: 1 ether }(p1);

        // Resolution deadline before closing timestamp
        ILongTailMarketFactory.CreateMarketParams memory p2 = ILongTailMarketFactory.CreateMarketParams({
            question: "Question 2",
            metadataURI: "",
            category: "DeFi",
            closingTimestamp: uint64(block.timestamp + 10 days),
            resolutionDeadline: uint64(block.timestamp + 5 days),
            resolver: address(0),
            pricingModel: address(0),
            b: 1 ether,
            feeBps: 100
        });
        vm.expectRevert(Errors.InvalidTimestamps.selector);
        factory.createMarket{ value: 1 ether }(p2);
        vm.stopPrank();
    }

    function test_RevertWhen_FeeTooHigh() public {
        vm.startPrank(creator);
        ILongTailMarketFactory.CreateMarketParams memory params = ILongTailMarketFactory.CreateMarketParams({
            question: "Will fee revert?",
            metadataURI: "",
            category: "AI",
            closingTimestamp: uint64(block.timestamp + 10 days),
            resolutionDeadline: uint64(block.timestamp + 15 days),
            resolver: address(0),
            pricingModel: address(0),
            b: 1 ether,
            feeBps: 600 // 6% > 5% max
        });

        vm.expectRevert(Errors.FeeTooHigh.selector);
        factory.createMarket{ value: 1 ether }(params);
        vm.stopPrank();
    }

    function test_UniqueMarketIDsAndPagination() public {
        vm.startPrank(creator);
        for (uint256 i = 0; i < 3; i++) {
            ILongTailMarketFactory.CreateMarketParams memory p = ILongTailMarketFactory.CreateMarketParams({
                question: string(abi.encodePacked("Question ", vm.toString(i))),
                metadataURI: "",
                category: "Technology",
                closingTimestamp: uint64(block.timestamp + 10 days),
                resolutionDeadline: uint64(block.timestamp + 15 days),
                resolver: address(0),
                pricingModel: address(0),
                b: 1 ether,
                feeBps: 50
            });
            (uint256 mId, ) = factory.createMarket{ value: 0.5 ether }(p);
            assertEq(mId, i + 1);
        }
        vm.stopPrank();

        assertEq(factory.getMarketCount(), 3);
        ILongTailMarketFactory.MarketView[] memory views = factory.getMarkets(0, 10);
        assertEq(views.length, 3);
        assertEq(views[0].marketId, 1);
        assertEq(views[1].marketId, 2);
        assertEq(views[2].marketId, 3);
    }
}
