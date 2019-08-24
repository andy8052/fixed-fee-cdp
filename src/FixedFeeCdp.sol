pragma solidity >=0.5.0;

contract Troller {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
}

contract cETH {
    function mint() external payable;
    function balanceOfUnderlying(address account) external returns (uint);
    function redeemUnderlying(uint redeemNum) external returns (uint);
}

contract cDAI {
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
}

contract DAI {
    function transfer(address, uint) external returns(bool);
    function transferFrom(address, address, uint) external returns (bool);
    function approve(address, uint) external returns (bool);
}

contract FixedFeeCdp {

    address troll = 0x2EAa9D77AE4D8f9cdD9FAAcd44016E746485bddb;
    address cETHaddr = 0xd6801a1DfFCd0a410336Ef88DeF4320D6DF1883e;
    address cDAIaddr = 0x6D7F0754FFeb405d23C51CE938289d4835bE3b14;
    address DAIaddr = 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa;
    address payable owner;
    address payable lender;
    uint public borrowAmount;
    uint public lendAmount;

    uint joined = 0;

    constructor (address payable lender_) public {
        lender = lender_;
    }

    function joinMintAndBorrow(uint borrow) public payable returns(bool){
        require(msg.sender == lender);
        require(joined == 0, "You can only call this once");
        borrowAmount = borrow;
        enter();

        lendAmount = msg.value;
        cETH ceth = cETH(cETHaddr);
        ceth.mint.value(msg.value)();

        borrowDai(borrow);
        joined = 1;

        return true;
    }

    function enter() internal {
        address[] memory markets = new address[](2);
        markets[0] = cDAIaddr; //DAI
        markets[1] = cETHaddr; //ETH
        Troller trolololol = Troller(troll);

        trolololol.enterMarkets(markets);
    }

    function borrowDai(uint borrow) internal {
        cDAI cdai = cDAI(cDAIaddr);
        uint success = cdai.borrow(borrow);
        require(success == 0);
        require(DAI(DAIaddr).transfer(msg.sender, borrow));
    }

    function repayAndRemove() public returns (bool){
        require(msg.sender == lender);
        returnDai();
        redeemEth();
        lender.transfer(address(this).balance);
        return true;
    }

    function returnDai() internal {
        uint amt = cDAI(cDAIaddr).borrowBalanceCurrent(address(this));
        require(DAI(DAIaddr).transferFrom(msg.sender, address(this), amt));
        DAI(DAIaddr).approve(cDAIaddr, amt);
        cDAI cdai = cDAI(cDAIaddr);
        uint success = cdai.repayBorrow(amt);
        require(success == 0);
    }

    function redeemEth() internal {
        lendAmount = cETH(cETHaddr).balanceOfUnderlying(address(this));
        cETH(cETHaddr).redeemUnderlying(lendAmount);
    }

    function getLoanAmount() public returns (uint) {
        return cDAI(cDAIaddr).borrowBalanceCurrent(address(this));
    }

    function() external payable { }

}