// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ILongTailMarket } from "./ILongTailMarket.sol";
import { IPricingModel } from "../pricing/IPricingModel.sol";
import { LongTailOutcomeToken } from "./LongTailOutcomeToken.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Errors } from "../libraries/Errors.sol";

/// @title LongTailMarket
/// @notice Core market instance implementation designed for EIP-1167 clone deployment.
/// @dev Manages native BOT collateral, LMSR trading, LP liquidity pools, and non-reentrant settlement.
contract LongTailMarket is ILongTailMarket, ReentrancyGuard {
    bool public initialized;
    MarketConfig public config;
    MarketStatus public status;

    address public factory;
    LongTailOutcomeToken public outcomeToken;

    uint256 public collateralBalance;
    uint256 public qYes;
    uint256 public qNo;
    uint256 public totalLpShares;
    uint256 public reservedSettlement;
    uint256 public totalVolume;
    uint256 public participantsCount;

    mapping(address => uint256) public lpBalances;
    mapping(address => bool) internal hasParticipated;

    modifier onlyFactory() {
        if (msg.sender != factory) revert Errors.Unauthorized();
        _;
    }

    modifier onlyResolver() {
        if (msg.sender != config.resolver) revert Errors.Unauthorized();
        _;
    }

    modifier onlyActive() {
        if (status != MarketStatus.ACTIVE) revert Errors.MarketNotActive();
        if (block.timestamp >= config.closingTimestamp) {
            _closeMarketInternal();
            revert Errors.TradingPeriodEnded();
        }
        _;
    }

    /// @notice Initializes the cloned market instance with configuration and seed collateral.
    function initialize(
        MarketConfig calldata config_,
        address factoryAddress_,
        address outcomeTokenAddress_
    ) external payable override {
        if (initialized) revert Errors.AlreadyInitialized();
        if (msg.value == 0) revert Errors.InvalidInitialLiquidity();
        if (config_.closingTimestamp <= block.timestamp) revert Errors.InvalidTimestamps();
        if (config_.resolutionDeadline <= config_.closingTimestamp) revert Errors.InvalidTimestamps();
        if (config_.resolver == address(0)) revert Errors.InvalidResolver();
        if (config_.pricingModel == address(0)) revert Errors.InvalidPricingModel();

        initialized = true;
        config = config_;
        factory = factoryAddress_;
        outcomeToken = LongTailOutcomeToken(outcomeTokenAddress_);

        status = MarketStatus.ACTIVE;
        collateralBalance = msg.value;
        totalLpShares = msg.value;
        lpBalances[config_.creator] = msg.value;

        participantsCount = 1;
        hasParticipated[config_.creator] = true;

        emit LiquidityAdded(config_.marketId, config_.creator, msg.value, msg.value);
    }

    function _closeMarketInternal() internal {
        if (status == MarketStatus.ACTIVE) {
            status = MarketStatus.CLOSED;
            emit MarketClosed(config.marketId, uint64(block.timestamp));
            emit MarketStatusChanged(config.marketId, MarketStatus.ACTIVE, MarketStatus.CLOSED);
        }
    }

    /// @notice Manually closes trading if closing timestamp has passed.
    function closeMarket() external override {
        if (block.timestamp < config.closingTimestamp) revert Errors.TradingPeriodActive();
        if (status != MarketStatus.ACTIVE) revert Errors.MarketAlreadyClosed();
        _closeMarketInternal();
    }

    /// @notice Resolver sets lifecycle status (e.g., PROPOSED or DISPUTED).
    function setStatus(MarketStatus newStatus) external override onlyResolver {
        MarketStatus oldStatus = status;
        status = newStatus;
        emit MarketStatusChanged(config.marketId, oldStatus, newStatus);
    }

    /// @notice Resolver finalizes outcome (RESOLVED_YES, RESOLVED_NO, or CANCELLED).
    function setOutcome(MarketStatus resolvedStatus) external override onlyResolver {
        if (
            resolvedStatus != MarketStatus.RESOLVED_YES &&
            resolvedStatus != MarketStatus.RESOLVED_NO &&
            resolvedStatus != MarketStatus.CANCELLED
        ) {
            revert Errors.InvalidOutcome();
        }

        MarketStatus oldStatus = status;
        status = resolvedStatus;

        if (resolvedStatus == MarketStatus.RESOLVED_YES) {
            reservedSettlement = qYes;
        } else if (resolvedStatus == MarketStatus.RESOLVED_NO) {
            reservedSettlement = qNo;
        } else {
            reservedSettlement = 0;
        }

        emit MarketStatusChanged(config.marketId, oldStatus, resolvedStatus);
    }

    /// @notice Buys outcome shares using native BOT with slippage protection.
    function buy(bool isYes, uint256 minSharesOut) external payable override onlyActive nonReentrant returns (uint256 sharesBought) {
        if (msg.value == 0) revert Errors.ZeroAmount();

        uint256 fee = (msg.value * config.feeBps) / 10000;
        uint256 netCost = msg.value - fee;

        IPricingModel pricing = IPricingModel(config.pricingModel);
        sharesBought = pricing.calcSharesForCost(config.b, qYes, qNo, isYes, netCost);

        if (sharesBought < minSharesOut) revert Errors.SlippageExceeded();
        if (sharesBought == 0) revert Errors.ZeroAmount();

        if (isYes) {
            qYes += sharesBought;
        } else {
            qNo += sharesBought;
        }

        collateralBalance += netCost;
        totalVolume += msg.value;

        if (!hasParticipated[msg.sender]) {
            hasParticipated[msg.sender] = true;
            participantsCount++;
        }

        // Mint ERC-1155 outcome tokens to buyer
        outcomeToken.mintOutcome(config.marketId, msg.sender, isYes, sharesBought);

        // Forward protocol fee to factory
        if (fee > 0) {
            (bool feeSent, ) = factory.call{ value: fee }("");
            if (!feeSent) revert Errors.TransferFailed();
        }

        emit PositionPurchased(config.marketId, msg.sender, isYes, sharesBought, netCost, fee);
    }

    /// @notice Sells outcome shares for native BOT with slippage protection.
    function sell(
        bool isYes,
        uint256 sharesIn,
        uint256 minBotOut
    ) external override onlyActive nonReentrant returns (uint256 botProceeds) {
        if (sharesIn == 0) revert Errors.ZeroAmount();

        uint256 userBalance = outcomeToken.balanceOf(
            msg.sender,
            outcomeToken.getTokenId(config.marketId, isYes)
        );
        if (userBalance < sharesIn) revert Errors.InsufficientBalance();

        IPricingModel pricing = IPricingModel(config.pricingModel);
        uint256 grossProceeds = pricing.getSellQuote(config.b, qYes, qNo, isYes, sharesIn);

        if (grossProceeds > collateralBalance) revert Errors.InsufficientLiquidity();

        uint256 fee = (grossProceeds * config.feeBps) / 10000;
        botProceeds = grossProceeds - fee;

        if (botProceeds < minBotOut) revert Errors.SlippageExceeded();

        // Burn ERC-1155 outcome tokens from seller
        outcomeToken.burnOutcome(config.marketId, msg.sender, isYes, sharesIn);

        if (isYes) {
            qYes -= sharesIn;
        } else {
            qNo -= sharesIn;
        }

        collateralBalance -= grossProceeds;
        totalVolume += botProceeds;

        // Transfer BOT proceeds to seller
        (bool sent, ) = msg.sender.call{ value: botProceeds }("");
        if (!sent) revert Errors.TransferFailed();

        // Transfer fee to factory
        if (fee > 0) {
            (bool feeSent, ) = factory.call{ value: fee }("");
            if (!feeSent) revert Errors.TransferFailed();
        }

        emit PositionSold(config.marketId, msg.sender, isYes, sharesIn, botProceeds, fee);
    }

    /// @notice Adds liquidity to the market pool and receives LP shares.
    function addLiquidity() external payable override onlyActive nonReentrant returns (uint256 lpSharesMinted) {
        if (msg.value == 0) revert Errors.ZeroAmount();

        uint256 currentPool = collateralBalance;
        if (currentPool == 0 || totalLpShares == 0) {
            lpSharesMinted = msg.value;
        } else {
            lpSharesMinted = (msg.value * totalLpShares) / currentPool;
        }

        totalLpShares += lpSharesMinted;
        lpBalances[msg.sender] += lpSharesMinted;
        collateralBalance += msg.value;

        if (!hasParticipated[msg.sender]) {
            hasParticipated[msg.sender] = true;
            participantsCount++;
        }

        emit LiquidityAdded(config.marketId, msg.sender, msg.value, lpSharesMinted);
    }

    /// @notice Removes available free liquidity; strictly protects reserved payout liabilities.
    function removeLiquidity(uint256 lpShares) external override nonReentrant returns (uint256 amountOut) {
        if (lpShares == 0) revert Errors.ZeroAmount();
        if (lpBalances[msg.sender] < lpShares) revert Errors.InsufficientLpShares();

        // Ensure withdrawals cannot touch maximum potential outcome payout liabilities
        uint256 maxLiability = qYes >= qNo ? qYes : qNo;
        if (status == MarketStatus.RESOLVED_YES || status == MarketStatus.RESOLVED_NO) {
            maxLiability = reservedSettlement;
        }

        if (collateralBalance <= maxLiability) {
            revert Errors.CannotWithdrawReservedCollateral();
        }

        uint256 freeCollateral = collateralBalance - maxLiability;
        amountOut = (freeCollateral * lpShares) / totalLpShares;
        if (amountOut == 0) revert Errors.CannotWithdrawReservedCollateral();

        lpBalances[msg.sender] -= lpShares;
        totalLpShares -= lpShares;
        collateralBalance -= amountOut;

        (bool sent, ) = msg.sender.call{ value: amountOut }("");
        if (!sent) revert Errors.TransferFailed();

        emit LiquidityRemoved(config.marketId, msg.sender, lpShares, amountOut);
    }

    /// @notice Redeems winning outcome tokens for 1 BOT per share after final resolution.
    function redeem() external override nonReentrant returns (uint256 payout) {
        if (status != MarketStatus.RESOLVED_YES && status != MarketStatus.RESOLVED_NO) {
            revert Errors.MarketNotResolved();
        }

        bool isYesWinner = (status == MarketStatus.RESOLVED_YES);
        uint256 winningTokenId = outcomeToken.getTokenId(config.marketId, isYesWinner);
        payout = outcomeToken.balanceOf(msg.sender, winningTokenId);

        if (payout == 0) revert Errors.NothingToRedeem();

        // Burn winning tokens
        outcomeToken.burnOutcome(config.marketId, msg.sender, isYesWinner, payout);

        if (payout > reservedSettlement) {
            payout = reservedSettlement;
        }

        reservedSettlement -= payout;
        collateralBalance -= payout;

        (bool sent, ) = msg.sender.call{ value: payout }("");
        if (!sent) revert Errors.TransferFailed();

        emit PositionRedeemed(config.marketId, msg.sender, payout, payout);
    }

    /// @notice Claims proportional refund if the market was cancelled.
    function claimRefund() external override nonReentrant returns (uint256 refundAmount) {
        if (status != MarketStatus.CANCELLED) revert Errors.InvalidStateTransition();

        uint256 yesBalance = outcomeToken.balanceOf(
            msg.sender,
            outcomeToken.getTokenId(config.marketId, true)
        );
        uint256 noBalance = outcomeToken.balanceOf(
            msg.sender,
            outcomeToken.getTokenId(config.marketId, false)
        );

        uint256 totalUserShares = yesBalance + noBalance;
        if (totalUserShares == 0) revert Errors.NothingToRedeem();

        if (yesBalance > 0) {
            outcomeToken.burnOutcome(config.marketId, msg.sender, true, yesBalance);
        }
        if (noBalance > 0) {
            outcomeToken.burnOutcome(config.marketId, msg.sender, false, noBalance);
        }

        uint256 totalShares = qYes + qNo;
        if (totalShares > 0) {
            refundAmount = (collateralBalance * totalUserShares) / totalShares;
        } else {
            refundAmount = 0;
        }

        if (refundAmount > collateralBalance) refundAmount = collateralBalance;
        collateralBalance -= refundAmount;

        (bool sent, ) = msg.sender.call{ value: refundAmount }("");
        if (!sent) revert Errors.TransferFailed();

        emit RefundClaimed(config.marketId, msg.sender, refundAmount);
    }

    // --- VIEW FUNCTIONS ---

    function getConfig() external view override returns (MarketConfig memory) {
        return config;
    }

    function getState() external view override returns (MarketState memory) {
        return MarketState({
            status: status,
            collateralBalance: collateralBalance,
            qYes: qYes,
            qNo: qNo,
            totalLpShares: totalLpShares,
            reservedSettlement: reservedSettlement,
            totalVolume: totalVolume,
            participantsCount: participantsCount
        });
    }

    function getProbability() external view override returns (uint256 pYes) {
        IPricingModel pricing = IPricingModel(config.pricingModel);
        return pricing.getProbability(config.b, qYes, qNo);
    }

    function getQuote(
        bool isYes,
        uint256 shares,
        bool isBuy
    ) external view override returns (uint256 costOrProceeds, uint256 fee) {
        IPricingModel pricing = IPricingModel(config.pricingModel);
        if (isBuy) {
            uint256 rawCost = pricing.getBuyQuote(config.b, qYes, qNo, isYes, shares);
            fee = (rawCost * config.feeBps) / 10000;
            costOrProceeds = rawCost + fee;
        } else {
            uint256 grossProceeds = pricing.getSellQuote(config.b, qYes, qNo, isYes, shares);
            fee = (grossProceeds * config.feeBps) / 10000;
            costOrProceeds = grossProceeds > fee ? grossProceeds - fee : 0;
        }
    }

    function getSharesForCost(
        bool isYes,
        uint256 investmentAmount
    ) external view override returns (uint256 expectedShares, uint256 fee) {
        if (investmentAmount == 0) return (0, 0);
        fee = (investmentAmount * config.feeBps) / 10000;
        uint256 netCost = investmentAmount - fee;
        IPricingModel pricing = IPricingModel(config.pricingModel);
        expectedShares = pricing.calcSharesForCost(config.b, qYes, qNo, isYes, netCost);
    }

    function getLpPosition(address provider) external view override returns (uint256 shares, uint256 withdrawableBot) {
        shares = lpBalances[provider];
        if (shares == 0 || totalLpShares == 0) return (0, 0);

        uint256 maxLiability = qYes >= qNo ? qYes : qNo;
        if (status == MarketStatus.RESOLVED_YES || status == MarketStatus.RESOLVED_NO) {
            maxLiability = reservedSettlement;
        }

        if (collateralBalance > maxLiability) {
            uint256 freeCollateral = collateralBalance - maxLiability;
            withdrawableBot = (freeCollateral * shares) / totalLpShares;
        } else {
            withdrawableBot = 0;
        }
    }

    receive() external payable {
        collateralBalance += msg.value;
    }
}
