pragma solidity ^0.5.10;

contract ProxyOwner {
    address owner;
    address lender;

    modifier auth() {
        require(
            msg.sender == owner || msg.sender == lender,
            "Only owner or lender can call this."
        );
        _;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the owner can call this."
        );
        _;
    }

    modifier onlyLender() {
        require(
            msg.sender == lender,
            "Only the lender can call this."
        );
        _;
    }
}

contract FixedFeeCdp {



}
