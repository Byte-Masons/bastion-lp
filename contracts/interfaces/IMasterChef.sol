// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface IMasterChef {
    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);

    struct PoolInfo {
        address lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. SADDLE to distribute per block.
        uint256 lastRewardBlock; // Last block number that SADDLE distribution occurs.
        uint256 accSaddlePerShare; // Accumulated SADDLE per share, times 1e12. See below.
    }

    function poolInfo(uint256 pid) external view returns (IMasterChef.PoolInfo memory);

    function totalAllocPoint() external view returns (uint256);

    function deposit(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function withdraw(
        uint256 pid,
        uint256 amount,
        address to
    ) external;
}
