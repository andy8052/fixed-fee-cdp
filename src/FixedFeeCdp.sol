pragma solidity >=0.5.0;

contract Troller {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
}

contract cETH {
    function mint() external payable;
    function redeemUnderlying(uint redeemNum) external returns (uint);
}

contract cDAI {
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
}

contract DAI {
    function transferFrom(address, uint) external returns (bool);
    function approve(address, uint) external returns (bool);
}

contract Compound {
    
    address troll = 0x2EAa9D77AE4D8f9cdD9FAAcd44016E746485bddb;
    address cETHaddr = 0xd6801a1DfFCd0a410336Ef88DeF4320D6DF1883e;
    address cDAIaddr = 0x6D7F0754FFeb405d23C51CE938289d4835bE3b14;
    address DAIaddr = 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa;
    address payable owner;
    address payable lender;
    uint public borrowAmount;
    uint public lendAmount;
    
    constructor (address payable owner_, address payable lender_) public {
        owner = owner_;
        lender = lender_;
    }
    
    function enter() public {
        address[] memory markets = new address[](2);
        markets[0] = cDAIaddr; //DAI
        markets[1] = cETHaddr; //ETH
        Troller trolololol = Troller(troll);
        
        trolololol.enterMarkets(markets);
        
        // cDAI cdai = cDAI(cDAIaddr);
        // uint success = cdai.mint(borrow);
        // require(success == 0);
    }
    
    function mintEth() public payable {
        lendAmount = msg.value;
        cETH ceth = cETH(cETHaddr);
        ceth.mint.value(msg.value)();
    }
    
    function redeemEth() public {
        cETH(cETHaddr).redeemUnderlying(lendAmount);
    }
    
    function borrowDai(uint borrow) public {
        cDAI cdai = cDAI(cDAIaddr);
        uint success = cdai.borrow(borrow);
        require(success == 0);
    }
    
    function returnDai() public {
        require(DAI(DAIaddr).transferFrom(msg.sender, borrowAmount));
        DAI(DAIaddr).approve(cDAIaddr, borrowAmount);
        cDAI cdai = cDAI(cDAIaddr);
        uint success = cdai.repayBorrow(borrowAmount);
        require(success == 0);
    }
    
    function joinMintAndBorrow(uint borrow) public payable {
        borrowAmount = borrow;
        enter();
        mintEth();
        borrowDai(borrow);
    }
    
    function repayAndRemove() public {
        returnDai();
        redeemEth();
        owner.transfer(lendAmount);
    }

}