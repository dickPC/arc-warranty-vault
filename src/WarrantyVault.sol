// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract WarrantyVault {
    IERC20 public immutable usdc;
    address public arbiter;

    struct Warranty {
        address seller;
        address buyer;
        uint256 deposit;
        uint256 expiresAt;
        bool claimed;
        bool refunded;
    }
    Warranty[] public warranties;

    event WarrantyCreated(uint256 indexed id, address seller, address buyer, uint256 deposit, uint256 expiresAt);
    event Claimed(uint256 indexed id, uint256 amount);
    event Released(uint256 indexed id);

    constructor(address _usdc) {
        require(_usdc != address(0), "BAD_USDC");
        usdc = IERC20(_usdc);
        arbiter = msg.sender;
    }

    modifier onlyArbiter() { require(msg.sender == arbiter, "NOT_ARBITER"); _; }

    function createWarranty(address buyer, uint256 deposit, uint256 duration) external {
        require(usdc.transferFrom(msg.sender, address(this), deposit), "DEPOSIT_FAILED");
        warranties.push(Warranty(msg.sender, buyer, deposit, block.timestamp + duration, false, false));
        emit WarrantyCreated(warranties.length - 1, msg.sender, buyer, deposit, block.timestamp + duration);
    }

    function claim(uint256 id) external onlyArbiter {
        Warranty storage w = warranties[id];
        require(!w.claimed && !w.refunded && block.timestamp <= w.expiresAt, "INVALID");
        w.claimed = true;
        require(usdc.transfer(w.buyer, w.deposit), "TRANSFER_FAILED");
        emit Claimed(id, w.deposit);
    }

    function release(uint256 id) external {
        Warranty storage w = warranties[id];
        require(!w.claimed && !w.refunded, "INVALID");
        require(block.timestamp > w.expiresAt || msg.sender == arbiter, "NOT_EXPIRED");
        w.refunded = true;
        require(usdc.transfer(w.seller, w.deposit), "TRANSFER_FAILED");
        emit Released(id);
    }
}
