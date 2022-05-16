// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface CErc20I {
    function mint(uint256 mintAmount) external returns (uint256);
}