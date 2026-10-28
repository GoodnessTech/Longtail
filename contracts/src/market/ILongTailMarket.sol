// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ILongTailMarket {
    enum MarketStatus {
        CREATED,
        ACTIVE,
        CLOSED,
        PROPOSED,
        DISPUTED,
        RESOLVED_YES,
        RESOLVED_NO,
        CANCELLED
    }

    struct MarketConfig {
        uint256 marketId;
        address creator;
        string question;
        string metadataURI;
        string category;
        uint64 createdAt;
        uint64 closingTimestamp;
        uint64 resolutionDeadline;
        address resolver;
        address pricingModel;
        uint256 b; // LMSR liquidity parameter
        uint16 feeBps; // Fee in basis points (100 = 1%)
    }

    struct MarketState {
        MarketStatus status;
        uint256 collateralBalance;
        uint256 qYes;
        uint256 qNo;
        uint256 totalLpShares;
        uint256 reservedSettlement;
        uint256 totalVolume;
        uint256 participantsCount;
    }

    event MarketClosed(uint256 indexed marketId, uint64 closedAt);
    event MarketStatusChanged(uint256 indexed marketId, MarketStatus indexed oldStatus, MarketStatus indexed newStatus);
    event PositionPurchased(uint256 indexed marketId, address indexed buyer, bool isYes, uint256 shares, uint256 cost, uint256 fee);
    event PositionSold(uint256 indexed marketId, address indexed seller, bool isYes, uint256 shares, uint256 proceeds, uint256 fee);
    event LiquidityAdded(uint256 indexed marketId, address indexed provider, uint256 amount, uint256 lpSharesMinted);
    event LiquidityRemoved(uint256 indexed marketId, address indexed provider, uint256 lpSharesBurned, uint256 amountReturned);
    event PositionRedeemed(uint256 indexed marketId, address indexed redeemer, uint256 shares, uint256 payout);
    event RefundClaimed(uint256 indexed marketId, address indexed account, uint256 refundAmount);

    function initialize(
        MarketConfig calldata config,
        address factoryAddress,
        address outcomeTokenAddress
    ) external payable;

    function buy(bool isYes, uint256 minSharesOut) external payable returns (uint256 sharesBought);
    function sell(bool isYes, uint256 sharesIn, uint256 minBotOut) external returns (uint256 botProceeds);
    function addLiquidity() external payable returns (uint256 lpSharesMinted);
    function removeLiquidity(uint256 lpShares) external returns (uint256 amountOut);
    function closeMarket() external;
    function setStatus(MarketStatus newStatus) external;
    function setOutcome(MarketStatus resolvedStatus) external;
    function redeem() external returns (uint256 payout);
    function claimRefund() external returns (uint256 refundAmount);

    function getConfig() external view returns (MarketConfig memory);
    function getState() external view returns (MarketState memory);
    function getProbability() external view returns (uint256 pYes);
    function getQuote(bool isYes, uint256 shares, bool isBuy) external view returns (uint256 costOrProceeds, uint256 fee);
    function getSharesForCost(bool isYes, uint256 investmentAmount) external view returns (uint256 expectedShares, uint256 fee);
    function getLpPosition(address provider) external view returns (uint256 shares, uint256 withdrawableBot);
}
