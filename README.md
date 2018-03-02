# GSTAR.AI Crowdsale Contracts

Refer below for more information about [GStar's Crowdsale][gstar.ai] and the crowdsale smart contracts.

![GStar.AI](images/logoHeaders.jpg)

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

## Smart Contracts




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
