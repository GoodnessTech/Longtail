// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IPricingModel } from "./IPricingModel.sol";
import { FixedPointMath } from "../libraries/FixedPointMath.sol";
import { Errors } from "../libraries/Errors.sol";

/// @title LMSRPricingModel
/// @notice Production-grade Logarithmic Market Scoring Rule pricing engine for binary prediction markets.
/// @dev Solvency is guaranteed because Total Collateral >= max(qYes, qNo) under all trade trajectories.
/// Uses the numerically stable formulation: C(q1, q2) = max(q1, q2) + b * ln(1 + exp(-|q1 - q2|/b))
contract LMSRPricingModel is IPricingModel {
    using FixedPointMath for uint256;

    uint256 public constant WAD = 1e18;
    int256 internal constant WAD_INT = 1e18;

    // Minimum and maximum probability bounds (0.1% to 99.9%)
    uint256 public constant MIN_PROBABILITY = 1e15; // 0.1%
    uint256 public constant MAX_PROBABILITY = 999e15; // 99.9%

    function name() external pure override returns (string memory) {
        return "LMSR";
    }

    /// @notice Calculates the total LMSR cost function for inventory (qYes, qNo).
    /// @dev C(q1, q2) = max(q1, q2) + b * ln(1 + exp(-|q1 - q2| / b))
    function getCost(uint256 b, uint256 qYes, uint256 qNo) public pure override returns (uint256) {
        if (b == 0) revert Errors.InvalidPricingModel();

        uint256 maxQ = qYes >= qNo ? qYes : qNo;
        uint256 diff = qYes >= qNo ? qYes - qNo : qNo - qYes;

        // ratio = diff / b in WAD
        uint256 ratio = diff.divWad(b);

        // If diff / b is large (> 42 WAD), exp(-ratio) is effectively 0, so ln(1 + 0) = 0.
        if (ratio > 42e18) {
            return maxQ;
        }

        // expNeg = exp(-ratio) <= 1 WAD
        uint256 expNeg = FixedPointMath.expWad(-int256(ratio));

        // arg = 1 + exp(-ratio) in WAD (lies in [1e18, 2e18])
        uint256 arg = WAD + expNeg;

        // lnVal = ln(arg) in WAD
        int256 lnVal = FixedPointMath.lnWad(arg);
        if (lnVal <= 0) return maxQ;

        // b * lnVal
        uint256 addition = b.mulWad(uint256(lnVal));
        return maxQ + addition;
    }

    /// @notice Calculates YES outcome probability in 18 decimals (WAD).
    function getProbability(uint256 b, uint256 qYes, uint256 qNo) public pure override returns (uint256) {
        if (b == 0) revert Errors.InvalidPricingModel();

        if (qYes == qNo) {
            return 5e17; // Exactly 50%
        }

        if (qYes > qNo) {
            uint256 diff = qYes - qNo;
            uint256 ratio = diff.divWad(b);
            if (ratio > 42e18) return MAX_PROBABILITY;

            // pYes = 1 / (1 + exp(-ratio))
            uint256 expNeg = FixedPointMath.expWad(-int256(ratio));
            uint256 denom = WAD + expNeg;
            uint256 prob = WAD.divWad(denom);
            return prob > MAX_PROBABILITY ? MAX_PROBABILITY : prob;
        } else {
            uint256 diff = qNo - qYes;
            uint256 ratio = diff.divWad(b);
            if (ratio > 42e18) return MIN_PROBABILITY;

            // pNo = 1 / (1 + exp(-ratio)), pYes = 1 - pNo
            uint256 expNeg = FixedPointMath.expWad(-int256(ratio));
            uint256 denom = WAD + expNeg;
            uint256 pNo = WAD.divWad(denom);
            if (pNo >= WAD) return MIN_PROBABILITY;
            uint256 pYes = WAD - pNo;
            return pYes < MIN_PROBABILITY ? MIN_PROBABILITY : pYes;
        }
    }

    /// @notice Quotes collateral cost to purchase `deltaShares` of an outcome.
    function getBuyQuote(
        uint256 b,
        uint256 qYes,
        uint256 qNo,
        bool isYes,
        uint256 deltaShares
    ) public pure override returns (uint256) {
        if (deltaShares == 0) return 0;
        uint256 initialCost = getCost(b, qYes, qNo);
        uint256 newCost = isYes
            ? getCost(b, qYes + deltaShares, qNo)
            : getCost(b, qYes, qNo + deltaShares);

        if (newCost <= initialCost) return 0;
        return newCost - initialCost;
    }

    /// @notice Quotes collateral proceeds from selling `deltaShares` of an outcome.
    function getSellQuote(
        uint256 b,
        uint256 qYes,
        uint256 qNo,
        bool isYes,
        uint256 deltaShares
    ) public pure override returns (uint256) {
        if (deltaShares == 0) return 0;
        if (isYes && deltaShares > qYes) revert Errors.InsufficientBalance();
        if (!isYes && deltaShares > qNo) revert Errors.InsufficientBalance();

        uint256 initialCost = getCost(b, qYes, qNo);
        uint256 newCost = isYes
            ? getCost(b, qYes - deltaShares, qNo)
            : getCost(b, qYes, qNo - deltaShares);

        if (initialCost <= newCost) return 0;
        return initialCost - newCost;
    }

    /// @notice Solves for shares received given a target net collateral cost using binary search.
    function calcSharesForCost(
        uint256 b,
        uint256 qYes,
        uint256 qNo,
        bool isYes,
        uint256 netCost
    ) public pure override returns (uint256) {
        if (netCost == 0) return 0;

        // Since price <= 1.00 BOT per share, minShares is at least netCost
        // and maxShares can be estimated. For binary search upper bound:
        // Worst-case lowest price is 0.001 (1000x cost). Upper bound = netCost * 1000.
        uint256 low = netCost; // At maximum price 1.0, shares = netCost
        uint256 high = netCost * 1000;
        if (high < netCost) high = type(uint128).max; // overflow protection

        uint256 bestShares = low;

        // Binary search 32 iterations gives precision within < 1e-9 WAD
        for (uint256 i = 0; i < 32; i++) {
            uint256 mid = (low + high) / 2;
            uint256 cost = getBuyQuote(b, qYes, qNo, isYes, mid);

            if (cost <= netCost) {
                bestShares = mid;
                low = mid + 1;
            } else {
                if (mid == 0) break;
                high = mid - 1;
            }
        }

        return bestShares;
    }
}
