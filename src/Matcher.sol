pragma solidity ^0.5.10;

import "./LenderTokenContract.sol";

contract CDAI {
    function borrowRatePerBlock() public view returns (uint256);
}

contract Oracle {
    function getUnderlyingPrice(address) public view returns (uint256);
}

contract _DAI {
    function transferFrom(address sender, address recipient, uint amount) public returns (bool);
    function transfer(address recipient, uint amount) public returns (bool);
    function approve(address spender, uint value) public returns (bool);
}

// h/t to https://github.com/makerdao/maker-otc
contract Matcher {
    event Test(uint256, uint256, uint256, uint256);
    event TokenCreated(address);

    uint private MAX_UINT = 2**256 - 1;

    _DAI dai;
    CDAI cdai;
    Oracle oracle;

    uint public term = 26 weeks;
    uint public maximum = 20000; // multiplier (in basis points) of current borrow rate that loans are safe until
    uint public collateralizationRatio = 15000; // minimum collateralization ratio (150% in bps)

    uint public minimumAmount = 1;

    struct Offer {
        // sorting information
        uint next;  // points to id of next higher offer
        uint previous;  // points to id of previous lower offer
        // economic information
        uint rate; // (minimum) fixed rate for which this offer is valid
        uint amount; // amount of ether associated with this offer
        address owner;
    }

    mapping(uint => Offer) public offers; // doubly linked list of sorted offer ids
    uint public best; // head of offers
    uint public worst; // tail of offers
    uint nextId = 1;

    constructor() public {
        // rinkeby addresses
        dai = _DAI(0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa);
        cdai = CDAI(0x6D7F0754FFeb405d23C51CE938289d4835bE3b14);
        oracle = Oracle(0x332B6e69f21ACdBA5fb3e8DaC56ff81878527E06);
    }

    function () external {
        revert("");
    }

    function offerExists(uint offerId) internal view returns (bool) {
        // this is a sufficient existence check because minimumAmount is enforced and guaranteed to be >0
        return offers[offerId].amount > 0;
    }

    function make(uint rate, uint amount, uint insertBefore) public payable {
        require(amount >= minimumAmount, "");
        require(dai.transferFrom(msg.sender, address(this), amount), "");

        uint id = nextId++;

        if (best == 0 && worst == 0) {
            // no orders exist
            best = id;
            worst = id;
            offers[id] = Offer(0, 0, rate, amount, msg.sender);
        } else {
            // >= 1 orders exist
            if (insertBefore == 0) {
                require(offers[best].rate > rate, "");
                offers[id] = Offer(best, 0, rate, amount, msg.sender);
                offers[best].previous = id;
                best = id;
            } else if (insertBefore == MAX_UINT) {
                require(offers[worst].rate <= rate, "");
                offers[id] = Offer(0, worst, rate, amount, msg.sender);
                offers[worst].next = id;
                worst = id;
            } else {
                require(offerExists(insertBefore) && insertBefore != best, "");
                require(offers[insertBefore].rate > rate, "");
                require(offers[offers[insertBefore].previous].rate <= rate, "");
                offers[id] = Offer(insertBefore, offers[insertBefore].previous, rate, amount, msg.sender);
                offers[insertBefore].previous = id;
            }
        }
    }

    function remove(uint offerId, address beneficiary) public {
        require(msg.sender == offers[offerId].owner, "");
        _remove(offerId, beneficiary, offers[offerId].amount);
    }

    function _remove(uint offerId, address beneficiary, uint amountToRefund) internal {
        require(offerExists(offerId), "");

        if (offerId == best) {
            best = offers[best].next;
        }

        if (offerId == worst) {
            worst = offers[worst].previous;
        }

        if (offerExists(offers[offerId].next)) {
            offers[offers[offerId].next].previous = offers[offerId].previous;
        }

        if (offerExists(offers[offerId].previous)) {
            offers[offers[offerId].previous].next = offers[offerId].next;
        }

        delete offers[offerId];

        if (amountToRefund > 0) {
            require(dai.transfer(beneficiary, amountToRefund), "");
        }
    }

    function getStabilityFee() public view returns (uint) {
        uint interestRate = cdai.borrowRatePerBlock();
        uint apr = interestRate * 2108160;
        return apr * 10000 / (1 * 10**18);

        // return 1800; // 18%, basis points
    }

    // oracle for dai price of eth
    function getDaiPrice() public view returns (uint) {
        return oracle.getUnderlyingPrice(address(cdai));

        // return 5 * (1 * 10**15); // .005 dai/ eth, basis points
    }

    // offer ids, rate, fillAmount, lastOfferFillAmount
    function matchOffers(uint daiToDraw) public view returns (uint[] memory, uint, uint, uint) {
        uint worstCaseFee = getStabilityFee() * maximum / 10000; // 4000
        // this is almost certainly not actually correct, fee probably compounds continuously...
        uint worstCaseFeeAmount = (daiToDraw * worstCaseFee / 10000) / (52 weeks / term);

        uint lastAmount;
        uint totalAmount = 0;
        uint nextOffer = best;
        uint i = 0;
        while (totalAmount < worstCaseFeeAmount) {
            require(offerExists(nextOffer), "");
            lastAmount = totalAmount;
            totalAmount += offers[nextOffer].amount;
            nextOffer = offers[nextOffer].next;
            i++;
        }

        uint j = 0;
        uint[] memory offerIds = new uint[](i);
        uint currentOffer = best;
        while (j < i) {
            offerIds[j] = currentOffer;
            currentOffer = offers[currentOffer].next;
            j++;
        }

        uint rate = offers[offerIds[offerIds.length - 1]].rate;

        uint lastOfferFillAmount;
        if (totalAmount > worstCaseFeeAmount) {
            lastOfferFillAmount = worstCaseFeeAmount - lastAmount;
        } else {
            lastOfferFillAmount = offers[offerIds[offerIds.length - 1]].amount;
        }

        return (offerIds, rate, worstCaseFeeAmount, lastOfferFillAmount);
    }

    function open(uint daiToDraw) public payable {
        uint[] memory offerIds;
        uint rate;
        uint totalOfferAmount;
        uint lastOfferAmount;

        (offerIds, rate, totalOfferAmount, lastOfferAmount) = matchOffers(daiToDraw);

        uint minimumEth = (daiToDraw * getDaiPrice() / (1*10**18)) * collateralizationRatio / 10000;

        // enforce that the cdp will be collateralized
        require(msg.value >= minimumEth, "");

        address[] memory offerAddresses = new address[](offerIds.length);
        uint[] memory offerAmounts = new uint[](offerIds.length);
        for (uint i; i < offerIds.length; i++) {
            offerAddresses[i] = offers[offerIds[i]].owner;
            if (i < offerIds.length - 1) {
                offerAmounts[i] = offers[offerIds[i]].amount;
            } else {
                offerAmounts[i] = lastOfferAmount;
            }
        }

        for (uint j; j < offerIds.length; j++) {
            if (j < offerIds.length - 1) {
              _remove(offerIds[j], address(this), 0);
            } else {
                _remove(offerIds[j], offerAddresses[j], offers[offerIds[j]].amount - lastOfferAmount);
            }
        }

        // this should compound continuously
        uint fixedRateFeeOnNominal = (daiToDraw * rate / 10000) / (52 weeks / term);

        emit Test(msg.value, totalOfferAmount, daiToDraw, fixedRateFeeOnNominal);

        LenderTokenContract token = new LenderTokenContract(address(dai), offerAddresses, offerAmounts, msg.sender);

        emit TokenCreated(address(token));

        dai.approve(address(token), uint(-1));
        token.deposit.value(msg.value)(totalOfferAmount, daiToDraw, fixedRateFeeOnNominal);
    }
}
