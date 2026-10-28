// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ILongTailMarketFactory } from "./ILongTailMarketFactory.sol";
import { ILongTailMarket } from "../market/ILongTailMarket.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Errors } from "../libraries/Errors.sol";

/// @title LongTailMarketFactory
/// @notice Central market creation and discovery registry deploying EIP-1167 clones for gas efficiency.
contract LongTailMarketFactory is ILongTailMarketFactory, Ownable, ReentrancyGuard {
    address public marketImplementation;
    address public outcomeToken;
    address public defaultResolver;
    address public defaultPricingModel;
    address public feeRecipient;

    uint256 public nextMarketId = 1;
    uint256 public totalProtocolFees;

    mapping(uint256 => address) public markets;
    mapping(address => uint256[]) public creatorMarkets;
    address[] public allMarkets;

    constructor(
        address implementation_,
        address outcomeToken_,
        address defaultResolver_,
        address defaultPricingModel_,
        address feeRecipient_
    ) Ownable(msg.sender) {
        if (implementation_ == address(0)) revert Errors.InvalidPricingModel();
        marketImplementation = implementation_;
        outcomeToken = outcomeToken_;
        defaultResolver = defaultResolver_;
        defaultPricingModel = defaultPricingModel_;
        feeRecipient = (feeRecipient_ == address(0)) ? msg.sender : feeRecipient_;
    }

    function setImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert Errors.InvalidPricingModel();
        marketImplementation = newImplementation;
        emit ImplementationUpdated(newImplementation);
    }

    function setDefaultResolver(address newResolver) external onlyOwner {
        if (newResolver == address(0)) revert Errors.InvalidResolver();
        defaultResolver = newResolver;
        emit DefaultResolverUpdated(newResolver);
    }

    function setDefaultPricingModel(address newPricingModel) external onlyOwner {
        if (newPricingModel == address(0)) revert Errors.InvalidPricingModel();
        defaultPricingModel = newPricingModel;
        emit DefaultPricingModelUpdated(newPricingModel);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert Errors.Unauthorized();
        feeRecipient = newRecipient;
        emit ProtocolFeeRecipientUpdated(newRecipient);
    }

    /// @notice Permissionless market creation deploying a minimal proxy clone.
    function createMarket(CreateMarketParams calldata params) external payable override nonReentrant returns (uint256 marketId, address marketAddress) {
        if (bytes(params.question).length == 0 || bytes(params.question).length > 500) revert Errors.InvalidQuestion();
        if (params.closingTimestamp <= block.timestamp) revert Errors.InvalidTimestamps();
        if (params.resolutionDeadline <= params.closingTimestamp) revert Errors.InvalidTimestamps();
        if (params.feeBps > 500) revert Errors.FeeTooHigh(); // Maximum 5%
        if (msg.value == 0) revert Errors.InvalidInitialLiquidity();

        address chosenResolver = params.resolver == address(0) ? defaultResolver : params.resolver;
        address chosenPricing = params.pricingModel == address(0) ? defaultPricingModel : params.pricingModel;

        if (chosenResolver == address(0)) revert Errors.InvalidResolver();
        if (chosenPricing == address(0)) revert Errors.InvalidPricingModel();

        marketId = nextMarketId++;

        // Deploy EIP-1167 minimal proxy clone
        marketAddress = Clones.clone(marketImplementation);

        ILongTailMarket.MarketConfig memory config = ILongTailMarket.MarketConfig({
            marketId: marketId,
            creator: msg.sender,
            question: params.question,
            metadataURI: params.metadataURI,
            category: params.category,
            createdAt: uint64(block.timestamp),
            closingTimestamp: params.closingTimestamp,
            resolutionDeadline: params.resolutionDeadline,
            resolver: chosenResolver,
            pricingModel: chosenPricing,
            b: params.b > 0 ? params.b : msg.value,
            feeBps: params.feeBps
        });

        // Initialize clone with seed liquidity
        ILongTailMarket(marketAddress).initialize{ value: msg.value }(config, address(this), outcomeToken);

        markets[marketId] = marketAddress;
        creatorMarkets[msg.sender].push(marketId);
        allMarkets.push(marketAddress);

        emit MarketCreated(
            marketId,
            marketAddress,
            msg.sender,
            params.question,
            params.category,
            params.closingTimestamp,
            params.resolutionDeadline,
            chosenResolver,
            chosenPricing,
            msg.value
        );
    }

    function getMarketAddress(uint256 marketId) external view override returns (address) {
        return markets[marketId];
    }

    function getMarketCount() external view override returns (uint256) {
        return allMarkets.length;
    }

    function getCreatorMarkets(address creator) external view returns (uint256[] memory) {
        return creatorMarkets[creator];
    }

    /// @notice Returns batched market view objects for frontend discovery and exploration.
    function getMarkets(uint256 offset, uint256 limit) external view override returns (MarketView[] memory) {
        uint256 total = allMarkets.length;
        if (offset >= total) return new MarketView[](0);

        uint256 end = offset + limit;
        if (end > total) end = total;
        uint256 count = end - offset;

        MarketView[] memory items = new MarketView[](count);
        for (uint256 i = 0; i < count; i++) {
            address mAddr = allMarkets[offset + i];
            ILongTailMarket m = ILongTailMarket(mAddr);
            ILongTailMarket.MarketConfig memory cfg = m.getConfig();
            ILongTailMarket.MarketState memory st = m.getState();

            uint256 prob = 5e17; // Default 50%
            try m.getProbability() returns (uint256 p) {
                prob = p;
            } catch {}

            items[i] = MarketView({
                marketId: cfg.marketId,
                marketAddress: mAddr,
                creator: cfg.creator,
                question: cfg.question,
                category: cfg.category,
                closingTimestamp: cfg.closingTimestamp,
                resolutionDeadline: cfg.resolutionDeadline,
                status: st.status,
                probabilityYes: prob,
                liquidity: st.collateralBalance,
                totalVolume: st.totalVolume,
                participantsCount: st.participantsCount
            });
        }

        return items;
    }

    function withdrawFees() external nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.ZeroAmount();
        (bool sent, ) = feeRecipient.call{ value: balance }("");
        if (!sent) revert Errors.TransferFailed();
    }

    receive() external payable {
        totalProtocolFees += msg.value;
    }
}
