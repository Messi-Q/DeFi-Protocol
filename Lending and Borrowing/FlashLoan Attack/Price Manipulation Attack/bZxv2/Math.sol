// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.4;

library Math {
    /**
     * @dev Get the most significant bit of the number,
            example: 0 ~ 1 => 0, 2 ~ 3 => 1, 4 ~ 7 => 2, 8 ~ 15 => 3,
            about use 606 ~ 672 gas
     * @param x The number
     * @return uint8 The significant bit of the number
     */
    function mostSignificantBit(uint256 x) internal pure returns (uint8) {
        uint256 t;
        uint8 r;
        if ((t = (x >> 128)) > 0) {
            x = t;
            r += 128;
        }
        if ((t = (x >> 64)) > 0) {
            x = t;
            r += 64;
        }
        if ((t = (x >> 32)) > 0) {
            x = t;
            r += 32;
        }
        if ((t = (x >> 16)) > 0) {
            x = t;
            r += 16;
        }
        if ((t = (x >> 8)) > 0) {
            x = t;
            r += 8;
        }
        if ((t = (x >> 4)) > 0) {
            x = t;
            r += 4;
        }
        if ((t = (x >> 2)) > 0) {
            x = t;
            r += 2;
        }
        if ((t = (x >> 1)) > 0) {
            x = t;
            r += 1;
        }
        return r;
    }

    // https://en.wikipedia.org/wiki/Integer_square_root
    /**
     * @dev Get the square root of the number
     * @param x The number, usually 10^36
     * @return int256 The square root of the number, usually 10^18
     */
    function sqrt(int256 x) internal pure returns (int256) {
        require(x >= 0, "negative sqrt");
        if (x < 3) {
            return (x + 1) / 2;
        }

        // binary estimate
        // inspired by https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_estimates
        uint8 n = mostSignificantBit(uint256(x));
        // make sure initial estimate > sqrt(x)
        // 2^ceil((n + 1) / 2) as initial estimate
        // 2^(n + 1) > x
        // => 2^ceil((n + 1) / 2) > 2^((n + 1) / 2) > sqrt(x)
        n = (n + 1) / 2 + 1;

        // modified babylonian method
        int256 next = int256(1 << n);
        int256 y;
        do {
            y = next;
            next = (next + x / next) >> 1;
        } while (next < y);
        return y;
    }
}
