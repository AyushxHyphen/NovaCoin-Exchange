// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title NovaCoin (NOVA)
/// @notice Simple ERC-20 token. The full supply is minted to the deployer,
///         who then transfers a portion into the NovaExchange contract to
///         act as the sellable reserve.
contract NovaCoin is ERC20 {
    constructor(uint256 initialSupplyWhole) ERC20("NovaCoin", "NOVA") {
        _mint(msg.sender, initialSupplyWhole * 10 ** decimals());
    }
}
