// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title FixedPointMath
/// @notice Arithmetic operations for 18-decimal fixed-point numbers (WAD).
/// @dev Inspired by Solmate and PRBMath with explicit overflow protection and bounds.
library FixedPointMath {
    uint256 internal constant WAD = 1e18;
    int256 internal constant WAD_INT = 1e18;

    error MathOverflow();
    error MathDivisionByZero();
    error MathOutOfBounds();

    function mulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            if iszero(or(iszero(x), eq(div(mul(x, y), x), y))) {
                revert(0, 0)
            }
            z := div(mul(x, y), 1000000000000000000)
        }
    }

    function divWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            if iszero(y) {
                revert(0, 0)
            }
            if iszero(or(iszero(x), eq(div(mul(x, 1000000000000000000), x), 1000000000000000000))) {
                revert(0, 0)
            }
            z := div(mul(x, 1000000000000000000), y)
        }
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            if iszero(or(iszero(x), eq(div(mul(x, y), x), y))) {
                revert(0, 0)
            }
            let prod := mul(x, y)
            z := div(prod, 1000000000000000000)
            if mod(prod, 1000000000000000000) {
                z := add(z, 1)
            }
        }
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            if iszero(y) {
                revert(0, 0)
            }
            if iszero(or(iszero(x), eq(div(mul(x, 1000000000000000000), x), 1000000000000000000))) {
                revert(0, 0)
            }
            let prod := mul(x, 1000000000000000000)
            z := div(prod, y)
            if mod(prod, y) {
                z := add(z, 1)
            }
        }
    }

    /// @notice Calculates natural exponential e^x for fixed-point 18-decimal x.
    /// @dev Bounds x between -42e18 and 130e18 to prevent overflow in uint256.
    function expWad(int256 x) internal pure returns (uint256) {
        unchecked {
            if (x < -42e18) return 0;
            if (x > 130e18) revert MathOverflow();

            // Transform x from 18-decimal fixed-point to 64.64 fixed-point format
            int256 x64 = (x << 64) / WAD_INT;

            // Factorize x = k * ln(2) + r
            int256 k = (x64 * 0x171547652B82FE1777D0FF) >> 128;
            int256 r = x64 - k * 0xB17217F7D1CF79ABC9E3B;

            // Evaluate 7th order minimax polynomial for e^r
            int256 y = 0x100000000000000000000000000000000;
            y = 0x100000000000000000000000000000000 + ((r * y) >> 128);
            y = 0x80000000000000000000000000000000 + ((r * y) >> 128);
            y = 0x15555555555555555555555555555555 + ((r * y) >> 128);
            y = 0x2AAAAAAAB020F4F2BFDAFF819EF689DA + ((r * y) >> 128);
            y = 0x55555555555555555555555555555555 + ((r * y) >> 128);
            y = 0x100000000000000000000000000000000 + ((r * y) >> 128);

            // Shift by k and rescale to WAD (18 decimals)
            uint256 ans = uint256(y) >> uint256(128 - k);
            return (ans * WAD) >> 64;
        }
    }

    /// @notice Calculates natural logarithm ln(x) for fixed-point 18-decimal x.
    /// @dev x must be strictly positive.
    function lnWad(uint256 x) internal pure returns (int256) {
        unchecked {
            if (x == 0) revert MathOutOfBounds();

            // Use bit-level decomposition: ln(x) = k * ln(2) + ln(y) where y in [1, 2)
            int256 k = 0;
            uint256 y = x;

            while (y < WAD) {
                y <<= 1;
                k -= 1;
            }
            while (y >= 2 * WAD) {
                y >>= 1;
                k += 1;
            }

            // At this point y is in [1e18, 2e18).
            // Let z = (y - 1) / (y + 1)
            int256 z = int256((y - WAD) * WAD / (y + WAD));
            int256 z2 = (z * z) / WAD_INT;

            // ln((1+z)/(1-z)) = 2 * (z + z^3/3 + z^5/5 + z^7/7 + ...)
            int256 sum = z;
            int256 term = (z * z2) / WAD_INT;
            sum += term / 3;
            term = (term * z2) / WAD_INT;
            sum += term / 5;
            term = (term * z2) / WAD_INT;
            sum += term / 7;
            term = (term * z2) / WAD_INT;
            sum += term / 9;

            int256 lnY = 2 * sum;
            int256 ln2 = 693147180559945309; // ln(2) in WAD (0.693147180559945309e18)

            return k * ln2 + lnY;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
