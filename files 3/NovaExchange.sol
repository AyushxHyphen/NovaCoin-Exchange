// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title NovaExchange
/// @notice Lets anyone buy NOVA with ETH and sell NOVA back for ETH,
///         priced along a linear bonding curve:
///
///             price(tokensSold) = BASE_PRICE + SLOPE * tokensSold
///
///         Buying moves the curve up (price rises), selling moves it
///         back down. The contract itself holds both the NOVA reserve
///         (to sell) and the ETH reserve (to buy back).
contract NovaExchange is ReentrancyGuard, Ownable {
    IERC20 public immutable token;

    // Curve parameters (price expressed in wei per WHOLE token)
    uint256 public constant BASE_PRICE = 1e14; // 0.0001 ETH starting price
    uint256 public constant SLOPE = 1e10;      // price increases by this much per token sold

    // Number of WHOLE tokens sold so far via the curve (not wei-scaled)
    uint256 public tokensSold;

    event Bought(address indexed buyer, uint256 ethIn, uint256 tokensOut, uint256 newPriceWei);
    event Sold(address indexed seller, uint256 tokensIn, uint256 ethOut, uint256 newPriceWei);

    constructor(address tokenAddress) Ownable(msg.sender) {
        token = IERC20(tokenAddress);
    }

    /// @notice Current price of the NEXT token, in wei.
    function currentPrice() public view returns (uint256) {
        return BASE_PRICE + SLOPE * tokensSold;
    }

    /// @dev Integer square root (Babylonian method).
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /// @notice Buy NOVA with ETH. Sends any leftover dust ETH back to the buyer.
    function buy() external payable nonReentrant {
        require(msg.value > 0, "Send ETH to buy");

        uint256 S = tokensSold;

        // Solve the integral of the curve for the number of whole tokens
        // that msg.value buys:
        //   C = (SLOPE/2)*S^2 + BASE_PRICE*S + msg.value
        //   S' = (-BASE_PRICE + sqrt(BASE_PRICE^2 + 2*SLOPE*C)) / SLOPE
        uint256 C = (SLOPE * S * S) / 2 + BASE_PRICE * S + msg.value;
        uint256 discriminant = BASE_PRICE * BASE_PRICE + 2 * SLOPE * C;
        uint256 sqrtDisc = _sqrt(discriminant);
        require(sqrtDisc > BASE_PRICE, "Payment too small");

        uint256 newS = (sqrtDisc - BASE_PRICE) / SLOPE;
        uint256 tokensOut = newS - S;
        require(tokensOut > 0, "Payment too small to buy 1 token");

        uint256 tokensOutWei = tokensOut * 1e18;
        require(token.balanceOf(address(this)) >= tokensOutWei, "Exchange out of NOVA reserve");

        // Recompute exact cost for the whole tokens actually purchased,
        // refund any dust ETH from rounding.
        uint256 exactCost = BASE_PRICE * tokensOut + (SLOPE * (newS * newS - S * S)) / 2;
        uint256 refund = msg.value - exactCost;

        tokensSold = newS;
        require(token.transfer(msg.sender, tokensOutWei), "Token transfer failed");

        if (refund > 0) {
            (bool sent, ) = msg.sender.call{value: refund}("");
            require(sent, "Refund failed");
        }

        emit Bought(msg.sender, exactCost, tokensOut, currentPrice());
    }

    /// @notice Sell whole NOVA tokens back to the curve for ETH.
    /// @dev Caller must approve() this contract for at least tokenAmountWhole * 1e18 first.
    function sell(uint256 tokenAmountWhole) external nonReentrant {
        require(tokenAmountWhole > 0, "Amount must be > 0");
        require(tokenAmountWhole <= tokensSold, "Cannot sell more than curve has sold");

        uint256 S = tokensSold;
        uint256 newS = S - tokenAmountWhole;

        // ETH out = integral of curve from newS to S
        uint256 ethOut = BASE_PRICE * tokenAmountWhole + (SLOPE * (S * S - newS * newS)) / 2;
        require(address(this).balance >= ethOut, "Exchange out of ETH reserve");

        require(
            token.transferFrom(msg.sender, address(this), tokenAmountWhole * 1e18),
            "Token transfer failed - did you approve()?"
        );

        tokensSold = newS;

        (bool sent, ) = msg.sender.call{value: ethOut}("");
        require(sent, "ETH transfer failed");

        emit Sold(msg.sender, tokenAmountWhole, ethOut, currentPrice());
    }

    /// @notice Owner can top up the ETH reserve (e.g. at launch) if desired.
    receive() external payable {}
}
