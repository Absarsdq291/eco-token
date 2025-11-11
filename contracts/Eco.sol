// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IEco } from "./interfaces/IEco.sol";

/**
 * @title Eco.
 * @author Absar Salahuddin.
 * @notice Basic ERC20 token with trading taxes.
 */
contract Eco is ERC20, Ownable, IEco {
    /* ========================== STATE VARIABLES ========================== */

    /// @inheritdoc IEco
    uint256 public constant PPM = 1000000;

    /// @inheritdoc IEco
    uint256 public constant LIQUIDITY_TAX = 20_000;

    /// @inheritdoc IEco
    uint256 public constant MARKETING_TAX = 20_000;

    /// @inheritdoc IEco
    uint256 public constant DEVELOPMENT_TAX = 10_000;

    /// @inheritdoc IEco
    uint256 public constant BURN_TAX = 10_000;

    /// @inheritdoc IEco
    address public marketingWallet;

    /// @inheritdoc IEco
    address public developmentWallet;

    /// @inheritdoc IEco
    address public liquidityPoolWallet;

    /// @inheritdoc IEco
    mapping(address => bool) public automatedMarketMakerPairs;

    /// @inheritdoc IEco
    mapping(address => bool) public isExcludedFromFees;

    /* ========================== CONSTRUCTOR ========================== */

    /**
     * @dev Initializes variables and ownership.
     * @param initialOwner_ The initial owner of the contract.
     * @param liquidityPoolWallet_ The liquidity pool wallet address.
     * @param presaleWallet_ The presale wallet address.
     * @param marketingWallet_ The marketing wallet address.
     * @param developmentWallet_ The development wallet address.
     * @param communityWallet_ The community wallet address.
     * @param vestedWallet_ The vested wallet address.
     */
    constructor(
        address initialOwner_,
        address liquidityPoolWallet_,
        address presaleWallet_,
        address marketingWallet_,
        address developmentWallet_,
        address communityWallet_,
        address vestedWallet_
    ) ERC20("Eco", "ECO") Ownable(initialOwner_) {
        if (
            liquidityPoolWallet_ == address(0) ||
            presaleWallet_ == address(0) ||
            marketingWallet_ == address(0) ||
            developmentWallet_ == address(0) ||
            communityWallet_ == address(0) ||
            vestedWallet_ == address(0)
        ) {
            revert InvalidAddress();
        }

        liquidityPoolWallet = liquidityPoolWallet_;
        marketingWallet = marketingWallet_;
        developmentWallet = developmentWallet_;

        isExcludedFromFees[address(this)] = true;
        isExcludedFromFees[initialOwner_] = true;
        isExcludedFromFees[liquidityPoolWallet_] = true;
        isExcludedFromFees[presaleWallet_] = true;
        isExcludedFromFees[marketingWallet_] = true;
        isExcludedFromFees[developmentWallet_] = true;
        isExcludedFromFees[communityWallet_] = true;
        isExcludedFromFees[vestedWallet_] = true;

        _mint(liquidityPoolWallet_, 500_000_000_000 * 10 ** decimals()); // 50%
        _mint(presaleWallet_, 250_000_000_000 * 10 ** decimals()); // 25%
        _mint(marketingWallet_, 150_000_000_000 * 10 ** decimals()); // 15%
        _mint(vestedWallet_, 50_000_000_000 * 10 ** decimals()); // 5%
        _mint(communityWallet_, 50_000_000_000 * 10 ** decimals()); // 5%
    }

    /* ========================== FUNCTIONS ========================== */

    /**
     * @inheritdoc IEco
     */
    function setAutomatedMarketMakerPair(address pair, bool state) external onlyOwner {
        if (pair == address(0)) {
            revert InvalidAddress();
        }

        if (automatedMarketMakerPairs[pair] == state) {
            revert InvalidAssignment();
        }

        automatedMarketMakerPairs[pair] = state;

        emit SetAutomatedMarketMakerPair(pair, state);
    }

    /**
     * @inheritdoc IEco
     */
    function excludeFromFees(address account, bool excluded) external onlyOwner {
        if (account == address(0)) {
            revert InvalidAddress();
        }

        if (isExcludedFromFees[account] == excluded) {
            revert InvalidAssignment();
        }

        isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    /**
     * @inheritdoc ERC20
     * @dev Overridden to implement tax logic.
     * @param from The address tokens are transferred from.
     * @param to The address tokens are transferred to.
     * @param amount The amount of tokens transferred.
     */
    function _update(address from, address to, uint256 amount) internal override {
        bool takeFee = true;

        // Skip fee logic for minting or burning.
        if (from == address(0) || to == address(0)) {
            takeFee = false;
        }

        // Skip fees for excluded addresses.
        if (isExcludedFromFees[from] || isExcludedFromFees[to]) {
            takeFee = false;
        }

        // Determine buy/sell (only for actual swaps where msg.sender != router).
        if (takeFee) {
            bool isBuy = automatedMarketMakerPairs[from];
            bool isSell = automatedMarketMakerPairs[to];

            if (isBuy || isSell) {
                // Split taxes (basis points — 1,000,000 = 100%).
                uint256 liquidityFee = (amount * LIQUIDITY_TAX) / PPM;
                uint256 marketingFee = (amount * MARKETING_TAX) / PPM;
                uint256 devFee = (amount * DEVELOPMENT_TAX) / PPM;
                uint256 burnFee = (amount * BURN_TAX) / PPM;

                // Distribute taxes.
                if (liquidityFee > 0) super._update(from, liquidityPoolWallet, liquidityFee);
                if (marketingFee > 0) super._update(from, marketingWallet, marketingFee);
                if (devFee > 0) super._update(from, developmentWallet, devFee);
                if (burnFee > 0) _burn(from, burnFee);

                uint256 totalFee = liquidityFee + marketingFee + devFee + burnFee;

                amount -= totalFee;
            }
        }

        super._update(from, to, amount);
    }
}
