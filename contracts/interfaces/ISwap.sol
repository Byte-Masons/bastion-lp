// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISwap {
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256);
}