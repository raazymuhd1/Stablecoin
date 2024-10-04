// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title AN INTERFACE FOR DSC Engine smart contract
 * @author Mohammed Raazy
 * @notice this is an interface or a template all function
 */

interface IDSCEngine {
    function depositCollateralAndMintDSC(address collateralToken, uint256 collateralAmount, uint256 amountDscToMint) external;

    function depositCollateral(address tokenCollateralAddress, uint256 collateralAmount) external;

    function mintDSC(uint256 amountDscToMint) external;

    function burnDSC(uint256 amount) external;

    function liquidate(address collateral, address user, uint256 debtToCover) external;

    function getHealthFactor(address user) external view returns(uint256);

}
