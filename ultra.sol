// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title Simple DEX Order Matching Example
/// @notice This is a minimal illustration for integrating a basic order matching system into a DEX-like contract.
///         It allows users to place buy and sell limit orders for an ERC20 token and matches orders when possible.

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract SimpleDEX {
    struct Order {
        address user;
        uint256 amount;
        uint256 price; // price in wei per token
        bool isBuy;    // true for buy order, false for sell order
    }

    IERC20 public token;
    Order[] public orderBook; // simple array-based order book

    event OrderPlaced(uint256 orderId, address indexed user, uint256 amount, uint256 price, bool isBuy);
    event OrderMatched(uint256 buyOrderId, uint256 sellOrderId, uint256 amount, uint256 price);

    constructor(address _token) {
        token = IERC20(_token);
    }

    /// @notice Place an order and try to match it against existing orders
    function placeOrder(uint256 amount, uint256 price, bool isBuy) external payable {
        require(amount > 0 && price > 0, "Invalid order params");

        if (isBuy) {
            // User sends ETH for buy order: price * amount
            require(msg.value == amount * price, "Incorrect ETH sent");
        } else {
            // Seller must approve tokens first
            require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        }

        Order memory newOrder = Order({
            user: msg.sender,
            amount: amount,
            price: price,
            isBuy: isBuy
        });

        // Try to match
        for (uint256 i = 0; i < orderBook.length; i++) {
            Order storage other = orderBook[i];
            // Match buy with sell orders and vice versa
            if (other.isBuy != isBuy && other.amount > 0 && other.price == price) {
                uint256 matchedAmount = amount < other.amount ? amount : other.amount;
                // Transfer tokens and ETH accordingly
                if (isBuy) {
                    // Buyer: msg.sender, Seller: other.user
                    token.transfer(msg.sender, matchedAmount);
                    payable(other.user).transfer(matchedAmount * price);
                } else {
                    // Seller: msg.sender, Buyer: other.user
                    token.transfer(other.user, matchedAmount);
                    payable(msg.sender).transfer(matchedAmount * price);
                }
                other.amount -= matchedAmount;
                amount -= matchedAmount;
                emit OrderMatched(isBuy ? orderBook.length : i, isBuy ? i : orderBook.length, matchedAmount, price);
                if (amount == 0) break; // order fully matched
            }
        }
        // If order is not fully filled, add remainder to order book
        if (amount > 0) {
            newOrder.amount = amount;
            orderBook.push(newOrder);
            emit OrderPlaced(orderBook.length - 1, msg.sender, amount, price, isBuy);
        }
    }

    // Helper: get number of open orders
    function getOrderBookLength() external view returns (uint256) {
        return orderBook.length;
    }
}