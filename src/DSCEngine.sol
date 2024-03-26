// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

import {IDSCEngine} from "./interfaces/IDSCEngine.sol";
import {DecentralizedStableCoin} from "./DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/*
 * @title DSCEngine
 * @author Patrick Collins
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged ( patokan ke harga dollar )
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * It should always over collateralized, at no point the system collateral backed $1 value less than a DSC value
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract DSCEngine is IDSCEngine, ReentrancyGuard {
    error DSCEngine_NeedsMoreThanZero();
    error DSCEngine_NotAllowedToken();
    error DSCEngine_TokenLengthMustBeSameWithPriceFeedAddresses();
    error DSCEngine_TransferFailed();
    error DSCEngine_BreaksHealthFactor();
    error DSCEngine_MintFailed();
    error DSCEngine_HealthFactorIsOk();
    error DSCEngine_HealthFactorNotImproved();

    ////////////////////// STATE VARIABLES ///////////////////////
    mapping(address token => address priceFeed) private s_tokenToPriceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // amount of collateral user has been deposited
    mapping(address user => uint256 dscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    DecentralizedStableCoin private immutable i_dsc;

    /////////////////// EVENTS /////////////////////////////
    event CollateralDeposited(address indexed depositor, address collateralToken, uint256 collateralAmount);
    event CollateralRedeemed(address from, address to, address collateralToken, uint256 amount);

    ////////////////////// MODIFIERS /////////////////////////
    modifier MoreThanZero(uint256 amount_) {
        if (amount_ <= 0) {
            revert DSCEngine_NeedsMoreThanZero();
        }

        _;
    }

    modifier isAllowedToken(address token) {
        // check whether the token has the price feed or not ( if not then the token is not allowed to deposit as collateral )
        if (s_tokenToPriceFeeds[token] == address(0)) {
            revert DSCEngine_NotAllowedToken();
        }
        _;
    }

    //////////////// FUNCTIONS /////////////////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscTokenAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine_TokenLengthMustBeSameWithPriceFeedAddresses();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_tokenToPriceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]); // insert all collateral tokens
        }

        i_dsc = DecentralizedStableCoin(dscTokenAddress);
    }

    /**
     * @notice follow CEI pattern ( Check, Effect, Interactions )
     */
    function depositCollateral(address tokenCollateralAddress, uint256 collateralAmount)
        public
        // CHECK HAPPENED IN MODIFIER
        MoreThanZero(collateralAmount)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        //  Effect
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += collateralAmount;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, collateralAmount);

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), collateralAmount);
        if(!success) {
            revert DSCEngine_TransferFailed();
        }
    }

    function redeemCollateral(address tokenCollateral, uint256 amountCollateral) public MoreThanZero(amountCollateral) {
        _redeemCollateral(tokenCollateral, amountCollateral, msg.sender, msg.sender);
        _revertIfTotalCollateralBelowHealthFactor(msg.sender);
    }

    function depositCollateralAndMintDSC(address collateralToken, uint256 collateralAmount, uint256 amountDscToMint) external {
        depositCollateral(collateralToken, collateralAmount);
        mintDSC(amountDscToMint);
    }

    function depositCollateralForDSC() external {}

    function redeemCollateralForDSC(address tokenCollateral, uint256 amountCollateral, uint256 amountDscToBurn) external {
        burnDSC(amountDscToBurn);
        redeemCollateral(tokenCollateral, amountCollateral);
    }

    function liquidate(address collateral, address user, uint256 debtToCover) external {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if(startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine_HealthFactorIsOk();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        uint256 collateralBonus = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateraToRedeem = tokenAmountFromDebtCovered + collateralBonus;

        _redeemCollateral(collateral, totalCollateraToRedeem, user, msg.sender);
        _burnDSC(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if(endingUserHealthFactor <= startingUserHealthFactor) {
             revert DSCEngine_HealthFactorNotImproved();
        }

        _revertIfTotalCollateralBelowHealthFactor(msg.sender);
    }

    /**
     * @notice user need to have more collateral then the DSC value  ( $100 collateral > $50 DSC value )
     * @notice that way, theres never be undercolloateral
     * @param amountDscToMint => amount DSC to mint
     */
    function mintDSC(uint256 amountDscToMint) public MoreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;

        // this checking to ensure that user can only mint DSC below their collateral value ( $100 collateral => mint DSC $50 )
        _revertIfTotalCollateralBelowHealthFactor(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if(!minted) {
            revert DSCEngine_MintFailed();
        }
    }

    function burnDSC(uint256 amount) public MoreThanZero(amount) {
        _burnDSC(amount, msg.sender, msg.sender);
         _revertIfTotalCollateralBelowHealthFactor(msg.sender);
    }

    function getHealtFactor() external view {}

    function getTokenAmountFromUsd(address collateral, uint256 usdAmountInWei) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeeds[collateral]);
        (, int256 price, , , ) = priceFeed.latestRoundData();

        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    ////////////////// INTERNAL & PRIVATE FUNCTIONS ///////////////////////////

    function _redeemCollateral(address tokenCollateral, uint256 amountCollateral, address from, address to) internal MoreThanZero(amountCollateral) {
        s_collateralDeposited[from][tokenCollateral] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateral, amountCollateral);

        bool success = IERC20(tokenCollateral).transfer(to, amountCollateral);
        if(!success) {
            revert DSCEngine_TransferFailed();
        }

    }

    function _burnDSC(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        if(!success) {
            revert DSCEngine_TransferFailed();
        }

        i_dsc.burn(amountDscToBurn);
    }

    function _getUserInformation(address user) private view returns(uint256 totalDscMinted, uint256 collateralValueInUsd) {
         totalDscMinted += s_DSCMinted[user];
         collateralValueInUsd = getAccountCollateralValue(user);
    }

     function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    /**
     * health factor is a checking to how close the user collateral amount to liquidation is 
     * if user collateral amount is  under collateral then it can be liquidated by anyone else;
     * @param user => user address
     */
    function _healthFactor(address user) private view returns(uint256) {
         (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getUserInformation(user);
         return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
       }

    function _revertIfTotalCollateralBelowHealthFactor(address user) internal view returns(uint256) {
        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine_BreaksHealthFactor();
        }

        return userHealthFactor;
    }

    ////////////////// public & external functions ////////////////////////////

     function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUsd) {
        for(uint256 i = 0; i < s_collateralTokens.length; i++) {
              address token = s_collateralTokens[i];
              uint256 amount = s_collateralDeposited[user][token];
              totalCollateralValueInUsd += getUsdValue(token, amount);
        }   

        return totalCollateralValueInUsd;
    }

     function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

     function getUsdValue(address token, uint256 amount) public view returns(uint256) {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeeds[token]);
            (,int256 price,,,) = priceFeed.latestRoundData();

            return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
     }

     function getUserInformation(address user) external view returns(uint256 totalDscMinted, uint256 collateralValueInUsd) {
         ( totalDscMinted, collateralValueInUsd ) = _getUserInformation(user);
         return (totalDscMinted, collateralValueInUsd);
     }

       function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getDsc() external view returns (address) {
        return address(i_dsc);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_tokenToPriceFeeds[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}