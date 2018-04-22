import ether from './helpers/ether';
import {advanceBlock} from './helpers/advanceToBlock';
import {increaseTimeTo, duration} from './helpers/increaseTime';
import latestTime from './helpers/latestTime';
import EVMThrow from './helpers/EVMThrow';

const utils = require('./helpers/Utils');

const BigNumber = web3.BigNumber;

const should = require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const GStarCrowdsale = artifacts.require('GStarCrowdsale');
const GStarToken = artifacts.require('GStarToken');

contract('GStarCrowdsale', function ([_, wallet, accounts]) {
    const rate = new BigNumber(10000);
    const value = ether(1.5);
    const belowPrefundMinimumValue = ether(0.9);
    const belowMinimumValue = ether(0.09);
    const tokenSupply = new BigNumber('1.6e27');
    const expectedTokenAmount = rate.mul(value);

    const owner = web3.eth.accounts[0];
    const authorized = web3.eth.accounts[1];
    const unauthorized = web3.eth.accounts[2];
    const anotherAuthorized = web3.eth.accounts[3];

    before(async function() {
        await advanceBlock();
        await increaseTimeTo(1531051200); // 8 Jul 2018 1200h, the same start time as hardcoded in contract
    });

    beforeEach(async function () {

        this.token = await GStarToken.new({from: owner});
        this.crowdsale = await GStarCrowdsale.new(
            rate,
            wallet,
            this.token.address,
            {from: owner}
        );

        await this.crowdsale.addToWhitelist(authorized, {from: owner});
        await this.crowdsale.addToWhitelist(anotherAuthorized, {from: owner});
        await this.crowdsale.startCrowdsale({from: owner});   
  });

    describe('prevalidation of token contribution', function () {
        describe('should accept payments', function () {

            it('from whitelisted contributors during funding period', async function () {
                await this.crowdsale.sendTransaction({value: belowPrefundMinimumValue, from: authorized}).should.be.fulfilled;
                await this.crowdsale.buyTokens(authorized, { value: belowPrefundMinimumValue, from: authorized }).should.be.fulfilled;
            });

            it('when contribution will equate weiRaised to funding goal', async function () {
                await this.crowdsale.changePrivateContribution(ether(37997), {from: owner});
                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.fulfilled;
                await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.fulfilled;
            });
        });

        describe('should not accept payments', function () {
            it('when crowdsale is inactive', async function () {
                await this.crowdsale.stopCrowdsale({from: owner});
                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.rejected;
                await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.rejected;
            });

            it('when contributor is not whitelisted', async function () {
                await this.crowdsale.sendTransaction({value: value, from: unauthorized}).should.be.rejected;
                await this.crowdsale.buyTokens(unauthorized, { value: value, from: unauthorized }).should.be.rejected;
            });


            it('when contribution is below minimum amount during funding period', async function () {
                await this.crowdsale.sendTransaction({value: belowMinimumValue, from: authorized}).should.be.rejected;
                await this.crowdsale.buyTokens(authorized, { value: belowMinimumValue, from: authorized }).should.be.rejected;
            });

            it('when contributor is different from beneficiary', async function () {
                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.fulfilled;
                await this.crowdsale.buyTokens(anotherAuthorized, { value: belowMinimumValue, from: authorized }).should.be.rejected;
            });

            it('when contribution will exceed funding goal', async function () {

                await this.crowdsale.changePrivateContribution(ether(75997.1), {from: owner});
                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.fulfilled;
                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.rejected;
            });
        });
    });

    describe('high level contribution process', function() {

        it('tokens should not deliver when there is lack of tokens (single contributor)', async function () {

            await this.crowdsale.sendTransaction({value: value, from: authorized});
            await this.crowdsale.buyTokens(authorized, { value: value, from: authorized });

            let currentRate = await this.crowdsale.getRate();
            let tokenValue = value * currentRate * 2;
            let transferValue = tokenValue - ether(0.00000000001);
            await this.token.transfer(this.crowdsale.address, transferValue, {from: owner});
            await this.crowdsale.releaseTokens([authorized], {from: owner}).should.be.rejected;
        });

        it('tokens should not deliver when there is lack of tokens (multiple contributors)', async function () {

            await this.crowdsale.sendTransaction({value: value, from: authorized});
            await this.crowdsale.sendTransaction({value: value, from: anotherAuthorized});

            let currentRate = await this.crowdsale.getRate();
            let tokenValue = value * currentRate * 2;
            let transferValue = tokenValue - ether(0.00000000001);
            await this.token.transfer(this.crowdsale.address, transferValue, {from: owner});
            await this.crowdsale.releaseTokens([authorized, anotherAuthorized], {from: owner}).should.be.rejected;
        });

        it('funding contribution, tokens delivered', async function () {

            await this.crowdsale.sendTransaction({value: value, from: anotherAuthorized}).should.be.fulfilled;
            await this.crowdsale.buyTokens(anotherAuthorized, { value: value, from: anotherAuthorized }).should.be.fulfilled;

            await this.token.transfer(this.crowdsale.address, ether(100000), {from: owner});
            await this.crowdsale.releaseTokens([anotherAuthorized], {from: owner});
            let balance = await this.token.balanceOf(anotherAuthorized);
            let expectedValue = value * 10800 * 2;
            balance.should.be.bignumber.equal(expectedValue);
        });
    });

    describe('bonus structure', function () {

         it('during day 1 is 10800', async function () {
             let rate = await this.crowdsale.getRate();
             assert.equal(rate, 10800);
         });

         it('day 2 onwards is 10000', async function () {
             await increaseTimeTo(latestTime() + duration.days(1) + duration.seconds(1));
             let rate = await this.crowdsale.getRate();
             assert.equal(rate, 10000);
         });
    });

    describe('close function', function () {
          it('should return remaining token in the contract back to owner', async function () {
              let initialBalance = await this.token.balanceOf(owner);
              await this.token.transfer(this.crowdsale.address, ether(100000), {from: owner});
              await this.crowdsale.close({from: owner});
              let afterBalance = await this.token.balanceOf(owner);
              initialBalance.should.be.bignumber.equal(afterBalance);
          });
    });

    describe('ownership control', function () {
        it('only owner can access whitelist functions', async function () {
            await this.crowdsale.addToWhitelist(unauthorized, {from: owner}).should.be.fulfilled;
            await this.crowdsale.addManyToWhitelist([unauthorized, authorized], {from: owner}).should.be.fulfilled;
            await this.crowdsale.removeFromWhitelist(unauthorized, {from: owner}).should.be.fulfilled;

            await this.crowdsale.addToWhitelist(unauthorized, {from: authorized}).should.be.rejected;
            await this.crowdsale.addManyToWhitelist([unauthorized, authorized], {from: authorized}).should.be.rejected;
            await this.crowdsale.removeFromWhitelist(unauthorized, {from: authorized}).should.be.rejected;
        });

        it('only owner can transferOwnership', async function () {
            await this.crowdsale.transferOwnership(authorized, {from: owner}).should.be.fulfilled;
            await this.crowdsale.transferOwnership(owner, {from: authorized}).should.be.fulfilled;
            await this.crowdsale.transferOwnership(authorized, {from: unauthorized}).should.be.rejected;
            await this.crowdsale.transferOwnership(authorized, {from: authorized}).should.be.rejected;
        });

        it('only owner can stop crowdsale', async function () {
            await this.crowdsale.stopCrowdsale({from: owner}).should.be.fulfilled;

            //stopping crowdsale requires crowdsale to be active
            await this.crowdsale.startCrowdsale({from: owner}).should.be.fulfilled;

            await this.crowdsale.stopCrowdsale({from: authorized}).should.be.rejected;
        });

        it('only owner can start crowdsale', async function () {
            //starting crowdsale requires crowdsale to be inactive
            await this.crowdsale.stopCrowdsale({from: owner}).should.be.fulfilled;
            await this.crowdsale.startCrowdsale({from: owner}).should.be.fulfilled;

            //starting crowdsale requires crowdsale to be inactive
            await this.crowdsale.stopCrowdsale({from: owner}).should.be.fulfilled;
            await this.crowdsale.startCrowdsale({from: authorized}).should.be.rejected;
        });

        it('only owner can release tokens', async function () {
            await increaseTimeTo(this.startTime);
            await this.crowdsale.sendTransaction({value: value, from: authorized});
            await this.crowdsale.sendTransaction({value: value, from: anotherAuthorized});
            await this.token.transfer(this.crowdsale.address, ether(100000), {from: owner});

            await this.crowdsale.releaseTokens([authorized, anotherAuthorized], {from: owner}).should.be.fulfilled;
            await this.crowdsale.releaseTokens([authorized, anotherAuthorized], {from: authorized}).should.be.rejected;
        });

        it('only owner can close', async function () {
            await increaseTimeTo(this.prefundStart);
            await this.token.transfer(this.crowdsale.address, ether(100000), {from: owner});
            await this.crowdsale.close({from: owner}).should.be.fulfilled;

            await this.token.transfer(this.crowdsale.address, ether(100000), {from: owner});
            await this.crowdsale.close({from: authorized}).should.be.rejected;
        });
    });

    describe('constructor parameters', function () {
        describe('should not initialize', function () {

            it('when wallet address is 0x0', async function () {
                try{
                    this.token = await GStarToken.new({from: owner});
                    this.crowdsale = await GStarCrowdsale.new(
                        rate,
                        0x0,
                        this.token.address,
                        {from: owner}
                    );
                } catch(error) {
                    return utils.ensureException(error);
                }
                assert(false, "did not throw with invalid wallet address");
            });

            it('when token address is 0x0', async function () {
                try{
                    this.token = await GStarToken.new({from: owner});
                    this.crowdsale = await GStarCrowdsale.new(
                        rate,
                        wallet,
                        0x0,
                        {from: owner}
                    );
                } catch(error) {
                    return utils.ensureException(error);
                }
                assert(false, "did not throw with invalid token address");
            });

            it('when rate is 0', async function () {
                try{
                    this.token = await GStarToken.new({from: owner});
                    this.crowdsale = await GStarCrowdsale.new(
                        0,
                        wallet,
                        this.token.address,
                        {from: owner}
                    );
                } catch(error) {
                    return utils.ensureException(error);
                }
                assert(false, "did not throw with zero rate");
            });
        });
    });

    describe('gas consumption for looping functions', function () {

        it('add a single address to whitelist with address input', async function () {

            return GStarCrowdsale.deployed().then(function(instance) {
                return instance.addToWhitelist(web3.eth.accounts[2], {from: owner}).should.be.fulfilled;
            }).then(function(result) {
                var gasUsed = new BigNumber(result.receipt.gasUsed);
                console.log("");
                console.log("        Adding a single address to whitelist with address input");
                console.log("        Gas Used for addToWhitelist        : " + gasUsed);
            })
        });

        it('add a single address to whitelist with array input', async function () {
            let accountArray = [];
            const length = 1; //1 accounts

            for(let i = 0; i < length; i++) {
                accountArray.push(web3.eth.accounts[i%10]);
            }

            return GStarCrowdsale.deployed().then(function(instance) {
                return instance.addManyToWhitelist(accountArray, {from: owner}).should.be.fulfilled;
            }).then(function(result) {
                var gasUsed = new BigNumber(result.receipt.gasUsed);
                console.log("");
                console.log("        Adding a single address to whitelist with array input");
                console.log("        Gas Used for addManyToWhitelist        : " + gasUsed);
            })
        });

        it('add 100 addresses to whitelist', async function () {
            let accountArray = [];
            const length = 100; //100 accounts

            for(let i = 0; i < length; i++) {
                accountArray.push(web3.eth.accounts[i%10]);
            }

            return GStarCrowdsale.deployed().then(function(instance) {
                return instance.addManyToWhitelist(accountArray, {from: owner}).should.be.fulfilled;
            }).then(function(result) {
                var gasUsed = new BigNumber(result.receipt.gasUsed);
                console.log("");
                console.log("        Adding 100 to whitelist");
                console.log("        Gas Used for addManyToWhitelist        : " + gasUsed);
            })
        });

        it('add 200 addresses to whitelist', async function () {
            let accountArray = [];
            const length = 200; //100 accounts

            for(let i = 0; i < length; i++) {
                accountArray.push(web3.eth.accounts[i%10]);
            }

            return GStarCrowdsale.deployed().then(function(instance) {
                return instance.addManyToWhitelist(accountArray, {from: owner}).should.be.fulfilled;
            }).then(function(result) {
                var gasUsed = new BigNumber(result.receipt.gasUsed);
                console.log("");
                console.log("        Adding 200 to whitelist");
                console.log("        Gas Used for addManyToWhitelist        : " + gasUsed);
            })
        });

        it('single transfer of tokens', async function () {
            return GStarToken.deployed().then(function(instance) {
                return instance.transfer(web3.eth.accounts[2], (value * rate), {from: owner}).should.be.fulfilled;
            }).then(function(result) {
                var gasUsed = new BigNumber(result.receipt.gasUsed);
                console.log("");
                console.log("        Single direct transfer of tokens");
                console.log("        Gas Used for transfer        : " + gasUsed);
            });
        });

        it('release tokens for a single address', async function () {
            let accountArray = [];
            const length = 1; //1 account

            for(let i = 0; i < length; i++) {
                accountArray.push(web3.eth.accounts[i%10]);
            }

            await this.crowdsale.addManyToWhitelist(accountArray, {from: owner});

            //sending funds to simulate contributing
            for(let i = 0; i < length; i++) {
                await this.crowdsale.sendTransaction({value: value, from: accountArray[i]});
            }
            await this.token.transfer(this.crowdsale.address, tokenSupply, {from: owner});
            return GStarCrowdsale.deployed().then(function(instance) {
                return instance.releaseTokens(accountArray, {from: owner}).should.be.fulfilled;
            }).then(function(result) {
                var gasUsed = new BigNumber(result.receipt.gasUsed);
                console.log("");
                console.log("        Release Tokens for single address");
                console.log("        Gas Used for ReleaseTokens        : " + gasUsed);
            });
        });

        it('release tokens to 100 addresses', async function () {
            let accountArray = [];
            const length = 100; //100 accounts

            for(let i = 0; i < length; i++) {
                accountArray.push(web3.eth.accounts[i%10]);
            }

            await this.crowdsale.addManyToWhitelist(accountArray, {from: owner});

            //sending funds to simulate contributing
            for(let i = 0; i < 10; i++) {
                await this.crowdsale.sendTransaction({value: value, from: accountArray[i]});
            }
            await this.token.transfer(this.crowdsale.address, tokenSupply, {from: owner});
            return GStarCrowdsale.deployed().then(function(instance) {
                return instance.releaseTokens(accountArray, {from: owner}).should.be.fulfilled;
            }).then(function(result) {
                var gasUsed = new BigNumber(result.receipt.gasUsed);
                console.log("");
                console.log("        Release Tokens for 100 address");
                console.log("        Gas Used for ReleaseTokens        : " + gasUsed);
            })
        });

        it('release tokens to 200 addresses', async function () {
            let accountArray = [];
            const length = 200; //200 accounts

            for(let i = 0; i < length; i++) {
                accountArray.push(web3.eth.accounts[i%10]);
            }

            await this.crowdsale.addManyToWhitelist(accountArray, {from: owner});

            //sending funds to simulate contributing
            for(let i = 0; i < 10; i++) {
                await this.crowdsale.sendTransaction({value: value, from: accountArray[i]});
            }
            await this.token.transfer(this.crowdsale.address, tokenSupply, {from: owner});
            return GStarCrowdsale.deployed().then(function(instance) {
                return instance.releaseTokens(accountArray, {from: owner}).should.be.fulfilled;
            }).then(function(result) {
                var gasUsed = new BigNumber(result.receipt.gasUsed);
                console.log("");
                console.log("        Release Tokens for 200 address");
                console.log("        Gas Used for ReleaseTokens        : " + gasUsed);
            });
        });
    });

    describe('after end time', function () {
        it('should not accept payment', async function () {
            await increaseTimeTo(latestTime() + duration.weeks(5));
            await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.rejected;
            await this.crowdsale.buyTokens(authorized,  {value: value, from: authorized}).should.be.rejected;
        });
    });
});
