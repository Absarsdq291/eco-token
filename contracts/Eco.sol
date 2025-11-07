// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Eco is ERC20, Ownable {
    constructor(address initialOwner) ERC20("Eco", "ECO") Ownable(initialOwner) {}
}
