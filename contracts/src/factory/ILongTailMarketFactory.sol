// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ILongTailMarket } from "../market/ILongTailMarket.sol";

interface ILongTailMarketFactory {
    struct CreateMarketParams {
        string question;
        string metadataURI;
        string category;
        uint64 closingTimestamp;
        uint64 resolutionDeadline;
        address resolver;
        address pricingModel;
        uint256 b; // LMSR liquidity parameter
        uint16 feeBps; // Fee basis points
    }

    struct MarketView {
        uint256 marketId;
        address marketAddress;
        address creator;
        string question;
        string category;
        uint64 closingTimestamp;
        uint64 resolutionDeadline;
        ILongTailMarket.MarketStatus status;
        uint256 probabilityYes;
        uint256 liquidity;
        uint256 totalVolume;
        uint256 participantsCount;
    }

    event MarketCreated(
        uint256 indexed marketId,
        address indexed marketAddress,
        address indexed creator,
        string question,
        string category,
        uint64 closingTimestamp,
        uint64 resolutionDeadline,
        address resolver,
        address pricingModel,
        uint256 initialLiquidity
    );

    event ProtocolFeeCollected(uint256 indexed marketId, uint256 amount);
    event ImplementationUpdated(address indexed newImplementation);
    event DefaultResolverUpdated(address indexed newResolver);
    event DefaultPricingModelUpdated(address indexed newPricingModel);
    event ProtocolFeeRecipientUpdated(address indexed newRecipient);

    function createMarket(CreateMarketParams calldata params) external payable returns (uint256 marketId, address marketAddress);
    function getMarketAddress(uint256 marketId) external view returns (address);
    function getMarketCount() external view returns (uint256);
    function getMarkets(uint256 offset, uint256 limit) external view returns (MarketView[] memory);
}
