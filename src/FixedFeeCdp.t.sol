pragma solidity ^0.5.10;

import "ds-test/test.sol";

import "./FixedFeeCdp.sol";

contract FixedFeeCdpTest is DSTest {
    FixedFeeCdp cdp;

    function setUp() public {
        cdp = new FixedFeeCdp();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
