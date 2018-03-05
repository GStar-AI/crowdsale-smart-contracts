# GSTAR.AI Crowdsale Contracts

Refer below for more information about [GStar's Crowdsale][gstar.ai] and the crowdsale smart contracts.

![GStar.AI](images/logosmall.png)

## Overview

## Contracts

## Crowdsale Specification
* GSTAR token is ERC-20 compliant.
* GSTAR token is hardcapped at 1.6 billion tokens.
* GSTAR token is non-mintable.
* Any excess token will be burned off by the owner at the end of the crowdsale.
* GSTAR tokens will be released only after the crowdsale ends.
* Contributors are required to be whitelisted.

### Token Distribution

![Token Distribution Chart](images/TokenDistribution.png)

## GSTAR Bonus Structure

| Period | Bonus Tokens |
| :---: | :---: |
| Pre-ICO | 20% |
| ICO Day 1 | 15% |
| ICO Day 2 to Day 3 | 12% |
| ICO Day 4 to Day 7 | 8% |
| ICO Week 2 | 4% |
| ICO Week 3 | 2% |
| ICO Week 4 | No Bonus |

## Development Framework

* The contracts are written in [Solidity][solidity] and tested using [Truffle][truffle] version [4.1.0][truffle_v4.1.0] and [Ganache CLI][ganache].
* The smart contracts are based on [OpenZeppelin][openzeppelin] framework version [1.7.0][openzeppelin_v1.7.0].

## Smart Contracts Functions

### GSTAR Tokens Function

**burn**
```javascript
function burn(uint256 _value) public onlyOwner
```
Allows owner to burn GSTAR tokens.

### GSTAR Crowdsale Functions

**buyTokens**
```javascript
function buyTokens(address beneficiary) public payable
```
Allows investors to purchase tokens by sending ETH directly to the contract. The fallback function will call the buyTokens function. The ETH received will be forwarded to the RefundVault. Investors can then claim their tokens or refund after the crowdsale ends.

**getRate**
```javascript
function getRate() public view returns (uint256)
```
Returns the number of GSTAR tokens per ETH sent. The rate varies accordingly with the mentioned bonus structure.

**updateFundingGoal**
```javascript
function updateFundingGoal() internal returns (bool)
```
Updates if the funding goal is reached. If the funding goal is reached, no more purchase of tokens is allowed.

**isFundingGoalReached**
```javascript
function isFundingGoalReached() public view returns (bool)
```
Shows if funding goal is reached.

**isCrowdsaleActive**
```javascript
function isCrowdsaleActive() public view returns (bool)
```
Shows if crowdsale is active.

**validPurchase**
```javascript
function validPurchase() internal view returns (bool)
```
Checks if the token purchase is within crowdsale period, if the crowdsale is active, and if the purchase is at least of the minimum amount. If these conditions are not met, investors cannot send ether to the crowdsale contract.

**startCrowdsale**
```javascript
function startCrowdsale() public onlyOwner
```
Allows owner to start/unpause crowdsale.

**stopCrowdsale**
```javascript
function stopCrowdsale() public onlyOwner
```
Allows owner to stop crowdsale or pause crowdsale in case of emergency.

**claimTokens**
```javascript
function claimTokens() public
```
Investors can claim the tokens purchased by simply calling this function after the crowdsale ends. Investors can only claim tokens with the address they send ETH with.

**claimRefund**
```javascript
function claimRefund() public
```
Investors can claim a full amount refund by calling this function after the crowdsale ends. Investors can only claim refund with the address they send ETH with.

**enableSettlement**
```javascript
function enableSettlement() public onlyOwner
```
Closes crowdsale and enable refund and release/claim of tokens.

**endSettlement**
```javascript
function endSettlement() public onlyOwner
```
End settlement period. No more refund or tokens can be claimed.

**addToWhitelist**
```javascript
function addToWhitelist(address beneficiary) public onlyOwner
```
Allows owner to add address to whitelist. Only whitelisted individuals can claim their tokens.

**removeFromWhitelist**
```javascript
function removeFromWhitelist(address beneficiary) public onlyOwner
```
Allows owner to remove address from whitelist.

**addManyToWhitelist**
```javascript
function addManyToWhitelist(address[] beneficiaries) public onlyOwner
```
Allows owner to add multiple addresses to the whitelist.

**whitelistAndReleaseTokens**
```javascript
function whitelistAndReleaseTokens(address[] beneficiaries) public onlyOwner
```
Allows owner to add multiple addresses to the whitelist and release tokens purchased to them.

#### GSTAR Crowdsale Events
**TokenPurchase**
```javascript
event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
```

**GoalReached**
```javascript
event GoalReached(uint256 totalEtherAmountRaised);
```

**OwnershipTransferred**
```javascript
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
```

**StartCrowdsale**
```javascript
event StartCrowdsale();
```

**StopCrowdsale**
```javascript
event StopCrowdsale();
```

**SettlementEnabled**
```javascript
event SettlementEnabled();
```

**SettlementEnded**
```javascript
event SettlementEnded();
```

**RefundClaimed**
```javascript
event RefundClaimed(address investor, uint256 etherWeiAmount, bool success);
```

**TokensClaimed**
```javascript
event TokensClaimed(address investor, uint256 tokensWeiAmount);
```

**Whitelisted**
```javascript
event Whitelisted(address beneficiary);
```

**Delisted**
```javascript
event Delisted(address beneficiary);
```

**AddedMultipleToWhitelist**
```javascript
event AddedMultipleToWhitelist(address[] beneficiaries);
```

**BulkWhitelistAndReleaseTokens**
```javascript
event BulkWhitelistAndReleaseTokens(address[] beneficiaries);
```

### RefundVault Functions

**deposit**
```javascript
function deposit(address investor, uint256 tokensWeiAmount) onlyOwner external payable
```
Deposits investors' ETH to the vault and update their new deposited value for ETH and GSTAR tokens.

**enableSettlement**
```javascript
function enableSettlement() onlyOwner external
```
Enable refund and claim of tokens.

**endSettlement**
```javascript
function endSettlement() onlyOwner external
```
End settlement period. No more refund or claim of tokens allowed.

**refund**
```javascript
function refund(address investor) onlyOwner external returns (bool)
```
Allows investors to claim a full amount refund through the crowdsale contract after the crowdsale ends.

**claimTokens**
```javascript
function claimTokens(address investor) onlyOwner external
```
Allows investors to claim tokens purchase through the crowdsale contract after the crowdsale ends.

**addToWhitelist**
```javascript
function addToWhiteList(address beneficiary) external onlyOwner
```
Adds address to whitelist.

**addManyToWhitelist**
```javascript
function addManyToWhitelist(address[] beneficiaries) external onlyOwner
```
Adds multiple addresses to whitelist.

**whitelistAndReleaseTokens**
```javascript
function whitelistAndReleaseTokens(address[] beneficiaries) external onlyOwner
```
Adds multiple addresses to whitelist and release tokens purchased for them.

**removeFromWhitelist**
```javascript
function removeFromWhitelist(address beneficiary) external onlyOwner
```
Remove address from whitelist.

**tokensDeposited**
```javascript
function tokensDeposited(address beneficiary) public view returns (uint256)
```
Shows the amount of purchased token deposited in the vault for each investor's address.

**etherDeposited**
```javascript
function etherDeposited(address beneficiary) public view returns (uint256)
```
Shows the amount of ETH deposited in the vault for each investor's address.

**isWhitelisted**
```javascript
function isWhitelisted(address beneficiary) public view returns (bool)
```
Shows if address is whitelisted.

#### RefundVault Events

**Deposited**
```javascript
event Deposited(address investor, uint256 etherWeiAmount, uint256 tokensWeiAmount);
```

**SettlementEnabled**
```javascript
event SettlementEnabled();
```

**SettlementEnded**
```javascript
event SettlementEnded();
```

**Refunded**
```javascript
event Refunded(address indexed beneficiary, uint256 weiAmount);
```

**TokensClaimed**
```javascript
event TokensClaimed(address investor, uint256 tokensWeiAmount);
```

**Whitelisted**
```javascript
event Whitelisted(address beneficiary);
```

**Delisted**
```javascript
event Delisted(address beneficiary);
```

**AddedMultipleToWhitelist**
```javascript
event AddedMultipleToWhitelist(address[] beneficiaries);
```

**BulkWhitelistAndReleaseTokens**
```javascript
event BulkWhitelistAndReleaseTokens(address[] beneficiaries);
```



### Dependencies
```
// Install truffle framework and initialize
$ npm install -g truffle
$ npm init

// Install ganache-cli which includes testrpc
$ npm install -g ganache-cli

// Install OpenZeppelin framework
$ npm install -E zeppelin-solidity

// Install node dependencies
$ npm install

// Install web3
$ npm install ethereum/web3.js
```


[gstar.ai]: https://gstar.ai/
[solidity]: https://solidity.readthedocs.io/en/develop/#
[truffle]: http://truffleframework.com/
[truffle_v4.1.0]: https://github.com/trufflesuite/truffle/releases/tag/v4.1.0
[ganache]: https://github.com/trufflesuite/ganache-cli
[openzeppelin]: https://openzeppelin.org/
[openzeppelin_v1.7.0]: https://github.com/OpenZeppelin/zeppelin-solidity/releases/tag/v1.7.0
