## Fixed Fee Compound Loans
This smart contract repo consists of 3 contracts which allow for users to be both makers and takers in fixed fee loans on [compound.finance](https://compound.finance)

### `Matcher.sol`
`rinkeby address: `
This contract is a matcher marketplace for fixed rate loans. I syncs up a loan taker with lenders who are willing to give them a fixed loan. If the borrower wants to take out a loan that is too big for one person, lenders can be grouped together.

### `LenderTokenContract.sol`
`rinkeby address: `
This contract is created by `Matcher` once the matching market desires to open up a loan. The contract mints an ERC20 which represents lenders shares of the collateral backing a borrowers stable loan. After the collateral position is closed, the ERC20 can be redeemed for a portion of the collateral.

### `FixedFeeCdp.sol`
`rinkeby address: `
This contract is the base of the code. It is created by `LenderTokenContract` and is designed to handle opening and closing the borrowers debt position on compound. After the position is closed the contract sends all of its `ETH` back to the `LenderTokenContract`.