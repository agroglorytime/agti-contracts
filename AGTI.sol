// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AGTI is ERC20Burnable, Ownable {

    constructor(address[2] memory account) ERC20("AGTI","AGTI") {
        _mint(account[0], 500000000);
        _mint(account[1], 500000000);
    }

    function decimals() public view override returns (uint8) {
        return 0;
    }

    function burn(uint256 amount) public override onlyOwner {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyOwner {
        super.burnFrom(account, amount);
    }
}