// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv3.sol";
import "./interfaces/IMasterChef.sol";
import "./interfaces/IUniswapV2Router02.sol";
import './interfaces/CErc20I.sol';
import './interfaces/ISwap.sol';
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @dev Deposit cUSDC-cUSDT LP in the MasterChef. Harvest BSTN rewards and recompound.
 */
contract ReaperStrategyBastionLP is ReaperBaseStrategyv3 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    address public constant TRISOLARIS_ROUTER = address(0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B);
    address public constant BASTION_ROUTER = address(0x6287e912a9Ccd4D5874aE15d3c89556b2a05f080);
    address public constant MASTER_CHEF = address(0x20D0E2D27D7d3f5420E68eBA474D4206431734D8);

    /**
     * @dev Tokens Used:
     * {NEAR} - Required for liquidity routing when doing swaps.
     * {BSTN} - Reward token for depositing LP into TShareRewardsPool.
     * {want} - Address of cUSDC-cUSDT LP token. (lowercase name for FE compatibility)
     * {USDT} - USDT - intermediate token to create LP
     * {USDC} - USDC - intermediate token to create LP
     * {lpToken0} - cUSDT (name for FE compatibility)
     * {lpToken1} - cUSDC (name for FE compatibility)
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
     * {bstnToNearPath} - to swap {BSTN} to {NEAR} (using TRISOLARIS_ROUTER)
     * {nearToUsdt} - to swap {NEAR} to {USDT} (using TRISOLARIS_ROUTER)
     * {nearToUsdc} - to swap {NEAR} to {USDC} (using TRISOLARIS_ROUTER)
     */
    address[] public bstnToNearPath;
    address[] public nearToUsdt;
    address[] public nearToUsdc;

    /**
     * @dev Bastion variables
     * {poolId} - ID of pool in which to deposit LP tokens
     */
    uint256 public poolId;

    /**
     * @dev Strategy variables
     * {chargeFeesInUsdc} - Can be set to charge fees in USDC
     */
    bool public chargeFeesInUsdc;

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
        nearToUsdc = [NEAR, USDC];
        nearToUsdt = [NEAR, USDT];
        poolId = 0;
        chargeFeesInUsdc = false;
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
        uint256 wantBal = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBal < _amount) {
            IMasterChef(MASTER_CHEF).withdraw(poolId, _amount - wantBal, address(this));
        }

        IERC20Upgradeable(want).safeTransfer(vault, _amount);
    }

    /**
     * @dev Core function of the strat, in charge of collecting and re-investing rewards.
     *      1. Claims {BSTN} from the {MASTER_CHEF}.
     *      2. Swaps {BSTN} to {NEAR} and charges fees.
     */
    function _harvestCore() internal override returns (uint256 callerFee) {
        _claimRewards();
        callerFee = _chargeFees();
    }

    function _claimRewards() internal {
        IMasterChef(MASTER_CHEF).harvest(poolId, address(this));
    }

    /**
     * @dev Helper function to swap tokens given an {_amount}, swap {_path}, and {_router}.
     */
    function _swap(
        uint256 _amount,
        address[] memory _path
    ) internal {
        if (_path.length < 2 || _amount == 0) {
            return;
        }

        IERC20Upgradeable(_path[0]).safeIncreaseAllowance(TRISOLARIS_ROUTER, _amount);
        IUniswapV2Router02(TRISOLARIS_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            0,
            _path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Core harvest function.
     *      Charges fees based on the amount of rewards earned
     */
    function _chargeFees() internal returns (uint256 callFeeToUser) {
        uint256 bstnBalance = IERC20Upgradeable(BSTN).balanceOf(address(this));
        _swap(bstnBalance, bstnToNearPath);
        uint256 nearBalance = IERC20Upgradeable(NEAR).balanceOf(address(this));
        IERC20Upgradeable feeToken;
        uint256 fee;
        if (chargeFeesInUsdc) {
            _swap(nearBalance * totalFee / PERCENT_DIVISOR, nearToUsdc);
            feeToken = IERC20Upgradeable(USDC);
            fee = feeToken.balanceOf(address(this));
        } else {
            feeToken = IERC20Upgradeable(NEAR);
            fee = feeToken.balanceOf(address(this)) * totalFee / PERCENT_DIVISOR;
        }
        if (fee != 0) {
            callFeeToUser = (fee * callFee) / PERCENT_DIVISOR;
            uint256 treasuryFeeToVault = (fee * treasuryFee) / PERCENT_DIVISOR;
            uint256 feeToStrategist = (treasuryFeeToVault * strategistFee) / PERCENT_DIVISOR;
            treasuryFeeToVault -= feeToStrategist;

            feeToken.safeTransfer(msg.sender, callFeeToUser);
            feeToken.safeTransfer(treasury, treasuryFeeToVault);
            feeToken.safeTransfer(strategistRemitter, feeToStrategist);
        }
    }

    /**
     * @dev Core harvest function. Adds more liquidity using {lpToken0} and {lpToken1}.
     */
    function addLiquidity() external {
        uint256 nearBalanceHalf = IERC20Upgradeable(NEAR).balanceOf(address(this)) / 2;

        if (nearBalanceHalf != 0) {
            _swap(nearBalanceHalf, nearToUsdt);
            _swap(nearBalanceHalf, nearToUsdc);

            uint256 usdtBalance = IERC20Upgradeable(USDT).balanceOf(address(this));
            uint256 usdcBalance = IERC20Upgradeable(USDC).balanceOf(address(this));
            
            IERC20Upgradeable(USDT).safeIncreaseAllowance(lpToken0, usdtBalance);
            IERC20Upgradeable(USDC).safeIncreaseAllowance(lpToken1, usdcBalance);
            CErc20I(lpToken0).mint(usdtBalance);
            CErc20I(lpToken1).mint(usdcBalance);

            uint256 lp0Balance = IERC20Upgradeable(lpToken0).balanceOf(address(this));
            uint256 lp1Balance = IERC20Upgradeable(lpToken1).balanceOf(address(this));

            if (lp0Balance != 0 && lp1Balance != 0) {
                IERC20Upgradeable(lpToken0).safeIncreaseAllowance(BASTION_ROUTER, lp0Balance);
                IERC20Upgradeable(lpToken1).safeIncreaseAllowance(BASTION_ROUTER, lp1Balance);
                uint256[] memory amounts = new uint256[](2);
                amounts[0] = lp0Balance;
                amounts[1] = lp1Balance;
                ISwap(BASTION_ROUTER).addLiquidity(
                    amounts,
                    1,
                    block.timestamp
                );
            }
        }
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
        IMasterChef(MASTER_CHEF).emergencyWithdraw(poolId, address(this));
    }

    /**
     * Changes which token fees are charged in.
     */
    function _setChargeFeesInUsdc(bool _chargeFeesInUsdc) external {
        _atLeastRole(STRATEGIST);
        chargeFeesInUsdc = _chargeFeesInUsdc;
    }
}
