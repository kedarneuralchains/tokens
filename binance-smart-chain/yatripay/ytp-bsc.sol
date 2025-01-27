// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts@5.2.0/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts@5.2.0/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts@5.2.0/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts@5.2.0/access/Ownable.sol";

/// @custom:security-contact rishabh@yatripay.com
contract YatriPay is ERC20, ERC20Burnable, ERC20Pausable, Ownable {

// Mapping to track blocked addresses
    mapping(address => bool) private blockedAddresses;

    constructor(address initialOwner)
        ERC20("Wrapped YatriPay", "WYTP")
        Ownable(initialOwner)
    {
        _mint(msg.sender, 25000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function blockAddress(address account) external onlyOwner {
        require(account != address(0), "Cannot block zero address");
        blockedAddresses[account] = true;
    }

    function unblockAddress(address account) external onlyOwner {
        require(account != address(0), "Cannot unblock zero address");
        blockedAddresses[account] = false;
    }

    function isBlocked(address account) external view returns (bool) {
        return blockedAddresses[account];
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // Overriding the _update function to add the block address logic
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        require(!blockedAddresses[from], "Sender address is blocked");
        require(!blockedAddresses[to], "Recipient address is blocked");
        super._update(from, to, value);
    }
}
