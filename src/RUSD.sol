// SPDX-Licenses-Identifier: MIT;
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStablecoin
 * @author Mohammed raazy
 * Collateral: exogenuos ( ETH & BTC )
 * Stability Mechanism: Algorithmic
 * Relative Stability: pegged to USD
 *
 * THIS CONTRACT IS MEANT TO BE GOVERNED BY DSCEngine, this contract is just an ERC20 implementation
 */
contract RUSD is ERC20Burnable, Ownable {
    error RUSD_MustBeMoreThanZero();
    error RUSD_BurnAmountExceedsBalance();
    error RUSD_CannotZeroAddress();

    address private immutable i_owner;

    event Token_Minted(address indexed sender, uint256 indexed amount);

    /**
     *
     * @param contractOwner_ whomever the owner of this contract
     */
    constructor(address contractOwner_) ERC20("RUSD", "RUSD") Ownable(contractOwner_) {
         i_owner = contractOwner_;
    }

    function burn(uint256 amount_) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (amount_ <= 0) {
            revert RUSD_MustBeMoreThanZero();
        } else if (balance < amount_) {
            revert RUSD_BurnAmountExceedsBalance();
        }

        super.burn(amount_);
    }

    function mint(address to_, uint256 amount_) external onlyOwner returns (bool) {
        if (msg.sender == address(0)) {
            revert RUSD_CannotZeroAddress();
        }

        if (amount_ <= 0) {
            revert RUSD_MustBeMoreThanZero();
        }

        _mint(to_, amount_);
        emit Token_Minted(msg.sender, amount_);
        return true;
    }

    function getOwner() external view returns(address) {
        return i_owner;
    }
}
