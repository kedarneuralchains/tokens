// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts@5.2.0/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts@5.2.0/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts@5.2.0/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts@5.2.0/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts@5.2.0/access/Ownable.sol";

/// @custom:security-contact rishabh@kedarneuralchains.com
contract Najem is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ERC20Permit {
    constructor(address initialOwner, address recipient)
        ERC20("Najem", "NJM")
        Ownable(initialOwner)
        ERC20Permit("Najem")
    {
        _mint(recipient, 100000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
