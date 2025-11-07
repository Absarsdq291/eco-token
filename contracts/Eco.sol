// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Eco is ERC20, Ownable {
    // Uniswap V3 Position Manager address (Ethereum Mainnet)
    address public constant UNISWAP_V3_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    // excluded from fees and max transaction amount
    mapping(address => bool) private _isExcludedFromFees;

    // Pools/Pairs
    mapping(address => bool) public automatedMarketMakerPairs;

    // Wallet addresses
    address public marketingWallet;
    address public developmentWallet;
    address public liquidityPoolWallet;

    // Tax rates (in basis points)
    uint256 public constant LIQUIDITY_TAX = 20_000; // 2%
    uint256 public constant MARKETING_TAX = 20_000; // 2%
    uint256 public constant DEVELOPMENT_TAX = 10_000; // 1%
    uint256 public constant BURN_TAX = 10_000; // 1%
    uint256 public constant TOTAL_TAX = LIQUIDITY_TAX + MARKETING_TAX + DEVELOPMENT_TAX + BURN_TAX; // 600 = 6%

    constructor(
        address initialOwner,
        address _liquidityPoolWallet,
        address _presaleWallet,
        address _marketingWallet,
        address _developmentWallet,
        address _communityWallet,
        address _vestedWallet
    ) ERC20("Eco", "ECO") Ownable(initialOwner) {
        require(
            _liquidityPoolWallet != address(0) &&
                _presaleWallet != address(0) &&
                _marketingWallet != address(0) &&
                _developmentWallet != address(0) &&
                _communityWallet != address(0) &&
                _vestedWallet != address(0),
            "Invalid wallet address"
        );

        // Store important wallets
        liquidityPoolWallet = _liquidityPoolWallet;
        marketingWallet = _marketingWallet;
        developmentWallet = _developmentWallet;

        // Exclude fee wallets and position manager from fees
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[_liquidityPoolWallet] = true;
        _isExcludedFromFees[_presaleWallet] = true;
        _isExcludedFromFees[_marketingWallet] = true;
        _isExcludedFromFees[_developmentWallet] = true;
        _isExcludedFromFees[_communityWallet] = true;
        _isExcludedFromFees[_vestedWallet] = true;

        // Token distribution
        _mint(_liquidityPoolWallet, 500_000_000_000 * 10 ** decimals()); // 50%
        _mint(_presaleWallet, 250_000_000_000 * 10 ** decimals()); // 25%
        _mint(_marketingWallet, 150_000_000_000 * 10 ** decimals()); // 15%
        _mint(_vestedWallet, 50_000_000_000 * 10 ** decimals()); // 5%
        _mint(_communityWallet, 50_000_000_000 * 10 ** decimals()); // 5%
    }

    function setAutomatedMarketMakerPair(address pair, bool state) public onlyOwner {
        require(automatedMarketMakerPairs[pair] != state, "Automated Market Maker Pair is already this state");
        automatedMarketMakerPairs[pair] = state;
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        require(account != address(0), "Invalid address");
        _isExcludedFromFees[account] = excluded;
    }

    function _update(address from, address to, uint256 amount) internal override {
        // Skip fee logic for minting or burning
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        // Skip fees for excluded addresses
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to] || msg.sender == UNISWAP_V3_POSITION_MANAGER) {
            super._update(from, to, amount);
            return;
        }

        // Determine buy/sell
        bool isBuy = automatedMarketMakerPairs[from];
        bool isSell = automatedMarketMakerPairs[to];

        // Apply tax
        if (isBuy) {
            // Split taxes (basis points — 10,000 = 100%)
            uint256 liquidityFee = (amount * LIQUIDITY_TAX) / 1000000;
            uint256 marketingFee = (amount * MARKETING_TAX) / 1000000;
            uint256 devFee = (amount * DEVELOPMENT_TAX) / 1000000;
            uint256 burnFee = (amount * BURN_TAX) / 1000000;

            uint256 totalFee = liquidityFee + marketingFee + devFee + burnFee;
            uint256 amountAfterFee = amount - totalFee;

            // Distribute taxes
            if (liquidityFee > 0) super._update(from, liquidityPoolWallet, liquidityFee);
            if (marketingFee > 0) super._update(from, marketingWallet, marketingFee);
            if (devFee > 0) super._update(from, developmentWallet, devFee);
            if (burnFee > 0) _burn(from, burnFee);

            // Transfer remaining tokens
            super._update(from, to, amountAfterFee);
        }
        else if (isSell) {
            // Split taxes (basis points — 10,000 = 100%)
            uint256 liquidityFee = (amount * LIQUIDITY_TAX) / 1000000;
            uint256 marketingFee = (amount * MARKETING_TAX) / 1000000;
            uint256 devFee = (amount * DEVELOPMENT_TAX) / 1000000;
            uint256 burnFee = (amount * BURN_TAX) / 1000000;

            // Distribute taxes
            if (liquidityFee > 0) super._update(from, liquidityPoolWallet, liquidityFee);
            if (marketingFee > 0) super._update(from, marketingWallet, marketingFee);
            if (devFee > 0) super._update(from, developmentWallet, devFee);
            if (burnFee > 0) _burn(from, burnFee);

            // Transfer tokens
            super._update(from, to, amount);
        } else {
            // Normal wallet-to-wallet transfer, no tax
            super._update(from, to, amount);
        }
    }
}
