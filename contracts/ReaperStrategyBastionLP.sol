// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv3.sol";
import "./interfaces/IMasterChef.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @dev Deposit TOMB-MAI LP in TShareRewardsPool. Harvest BSTN rewards and recompound.
 */
contract ReaperStrategyBastionLP is ReaperBaseStrategyv3 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    address public constant TRISOLARIS_ROUTER = address(0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B);
    address public constant MASTER_CHEF = address(0x20D0E2D27D7d3f5420E68eBA474D4206431734D8);

    /**
     * @dev Tokens Used:
     * {NEAR} - Required for liquidity routing when doing swaps.
     * {BSTN} - Reward token for depositing LP into TShareRewardsPool.
     * {want} - Address of TOMB-MAI LP token. (lowercase name for FE compatibility)
     * {lpToken0} - TOMB (name for FE compatibility)
     * {lpToken1} - MAI (name for FE compatibility)
     */
    address public constant NEAR = address(0xC42C30aC6Cc15faC9bD938618BcaA1a1FaE8501d);
    address public constant BSTN = address(0x9f1F933C660a1DC856F0E0Fe058435879c5CCEf0);
    address public constant want = address(0x0039f0641156cac478b0DebAb086D78B66a69a01);
    address public constant USDT = address(0x4988a896b1227218e4A686fdE5EabdcAbd91571f);
    address public constant USDC = address(0xB12BFcA5A55806AaF64E99521918A4bf0fC40802);
    address public constant lpToken0 = address(0x845E15A441CFC1871B7AC610b0E922019BaD9826);
    address public constant lpToken1 = address(0xe5308dc623101508952948b141fD9eaBd3337D99);

    /**
     * @dev Paths used to swap tokens:
     * {bstnToNearPath} - to swap {BSTN} to {NEAR} (using SPOOKY_ROUTER)
     * {nearToLP0} - to swap {NEAR} to {lpToken0} (using SPOOKY_ROUTER)
     * {nearToLP1} - to swap half of {lpToken0} to {lpToken1} (using TOMB_ROUTER)
     */
    address[] public bstnToNearPath;
    address[] public nearToLP0;
    address[] public nearToLP1;

    /**
     * @dev Tomb variables
     * {poolId} - ID of pool in which to deposit LP tokens
     */
    uint256 public poolId;

    /**
     * @dev Initializes the strategy. Sets parameters and saves routes.
     * @notice see documentation for each variable above its respective declaration.
     */
    function initialize(
        address _vault,
        address[] memory _feeRemitters,
        address[] memory _strategists,
        address[] memory _multisigRoles
    ) public initializer {
        __ReaperBaseStrategy_init(_vault, _feeRemitters, _strategists, _multisigRoles);
        bstnToNearPath = [BSTN, NEAR];
        nearToLP0 = [NEAR, lpToken0];
        nearToLP1 = [NEAR, lpToken1];
        poolId = 0;
    }

    /**
     * @dev Function that puts the funds to work.
     *      It gets called whenever someone deposits in the strategy's vault contract.
     */
    function _deposit() internal override {
        uint256 wantBalance = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBalance != 0) {
            IERC20Upgradeable(want).safeIncreaseAllowance(MASTER_CHEF, wantBalance);
            IMasterChef(MASTER_CHEF).deposit(poolId, wantBalance, address(this));
        }
    }

    /**
     * @dev Withdraws funds and sends them back to the vault.
     */
    function _withdraw(uint256 _amount) internal override {
        // uint256 wantBal = IERC20Upgradeable(want).balanceOf(address(this));
        // if (wantBal < _amount) {
        //     IMasterChef(TSHARE_REWARDS_POOL).withdraw(poolId, _amount - wantBal);
        // }

        // IERC20Upgradeable(want).safeTransfer(vault, _amount);
    }

    /**
     * @dev Core function of the strat, in charge of collecting and re-investing rewards.
     *      1. Claims {BSTN} from the {TSHARE_REWARDS_POOL}.
     *      2. Swaps {BSTN} to {NEAR} using {SPOOKY_ROUTER}.
     *      3. Claims fees for the harvest caller and treasury.
     *      4. Swaps the {NEAR} token for {lpToken0} using {SPOOKY_ROUTER}.
     *      5. Swaps half of {lpToken0} to {lpToken1} using {TOMB_ROUTER}.
     *      6. Creates new LP tokens and deposits.
     */
    function _harvestCore() internal override returns (uint256 callerFee) {
        // IMasterChef(TSHARE_REWARDS_POOL).deposit(poolId, 0); // deposit 0 to claim rewards

        // uint256 tshareBal = IERC20Upgradeable(BSTN).balanceOf(address(this));
        // _swap(tshareBal, bstnToNearPath, SPOOKY_ROUTER);

        // callerFee = _chargeFees();

        // uint256 wftmBal = IERC20Upgradeable(NEAR).balanceOf(address(this));
        // _swap(wftmBal, nearToLP0, SPOOKY_ROUTER);
        // uint256 tombHalf = IERC20Upgradeable(lpToken0).balanceOf(address(this)) / 2;
        // _swap(tombHalf, nearToLP1, TOMB_ROUTER);

        // _addLiquidity();
        // deposit();
    }

    /**
     * @dev Helper function to swap tokens given an {_amount}, swap {_path}, and {_router}.
     */
    function _swap(
        uint256 _amount,
        address[] memory _path,
        address _router
    ) internal {
        if (_path.length < 2 || _amount == 0) {
            return;
        }

        IERC20Upgradeable(_path[0]).safeIncreaseAllowance(_router, _amount);
        IUniswapV2Router02(_router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            0,
            _path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Core harvest function.
     *      Charges fees based on the amount of NEAR gained from reward
     */
    function _chargeFees() internal returns (uint256 callerFee) {
        IERC20Upgradeable wftm = IERC20Upgradeable(NEAR);
        uint256 wftmFee = (wftm.balanceOf(address(this)) * totalFee) / PERCENT_DIVISOR;
        if (wftmFee != 0) {
            callerFee = (wftmFee * callFee) / PERCENT_DIVISOR;
            uint256 treasuryFeeToVault = (wftmFee * treasuryFee) / PERCENT_DIVISOR;
            uint256 feeToStrategist = (treasuryFeeToVault * strategistFee) / PERCENT_DIVISOR;
            treasuryFeeToVault -= feeToStrategist;

            wftm.safeTransfer(msg.sender, callerFee);
            wftm.safeTransfer(treasury, treasuryFeeToVault);
            wftm.safeTransfer(strategistRemitter, feeToStrategist);
        }
    }

    /**
     * @dev Core harvest function. Adds more liquidity using {lpToken0} and {lpToken1}.
     */
    function _addLiquidity() internal {
        // uint256 lp0Bal = IERC20Upgradeable(lpToken0).balanceOf(address(this));
        // uint256 lp1Bal = IERC20Upgradeable(lpToken1).balanceOf(address(this));

        // if (lp0Bal != 0 && lp1Bal != 0) {
        //     IERC20Upgradeable(lpToken0).safeIncreaseAllowance(TOMB_ROUTER, lp0Bal);
        //     IERC20Upgradeable(lpToken1).safeIncreaseAllowance(TOMB_ROUTER, lp1Bal);
        //     IUniswapV2Router02(TOMB_ROUTER).addLiquidity(
        //         lpToken0,
        //         lpToken1,
        //         lp0Bal,
        //         lp1Bal,
        //         0,
        //         0,
        //         address(this),
        //         block.timestamp
        //     );
        // }
    }

    /**
     * @dev Function to calculate the total {want} held by the strat.
     *      It takes into account both the funds in hand, plus the funds in the MasterChef.
     */
    function balanceOf() public view override returns (uint256) {
        (uint256 amount, ) = IMasterChef(MASTER_CHEF).userInfo(poolId, address(this));
        return amount + IERC20Upgradeable(want).balanceOf(address(this));
    }

    /**
     * Withdraws all funds leaving rewards behind.
     */
    function _reclaimWant() internal override {
        // IMasterChef(TSHARE_REWARDS_POOL).emergencyWithdraw(poolId);
    }
}
