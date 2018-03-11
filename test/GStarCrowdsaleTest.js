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
    const tokenSupply = new BigNumber('8e26');
    const expectedTokenAmount = rate.mul(value);
    let owner = web3.eth.accounts[0];
    let authorized = web3.eth.accounts[1];
    let unauthorized = web3.eth.accounts[2];
    let anotherAuthorized = web3.eth.accounts[3];

    before(async function() {
        await advanceBlock();
    });

    beforeEach(async function () {

        //assuming prefund last 2 weeks, the actual ICO last 4 weeks
        this.deployTime = latestTime() + duration.days(1);
        this.prefundStart = this.deployTime + duration.weeks(6);
        this.startTime = this.prefundStart + duration.weeks(2);
        this.endTime = this.startTime + duration.weeks(4);

        this.token = await GStarToken.new({from: owner});
        this.crowdsale = await GStarCrowdsale.new(
            this.prefundStart,
            this.startTime,
            this.endTime,
            rate,
            wallet,
            this.token.address,
            {from: owner}
        );

        await this.crowdsale.addToWhitelist(authorized, {from: owner});
        await this.crowdsale.addToWhitelist(anotherAuthorized, {from: owner});
        await this.crowdsale.startCrowdsale({from: owner});
        await increaseTimeTo(this.deployTime);
  });

    describe('prevalidation of token contribution', function () {
        describe('should accept payments', function () {
            it('from whitelisted contributors during prefund period', async function () {
                await increaseTimeTo(this.prefundStart);

                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.fulfilled;
                await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.fulfilled;
            });
            it('from whitelisted contributors during funding period', async function () {
                await increaseTimeTo(this.startTime);

                await this.crowdsale.sendTransaction({value: belowPrefundMinimumValue, from: authorized}).should.be.fulfilled;
                await this.crowdsale.buyTokens(authorized, { value: belowPrefundMinimumValue, from: authorized }).should.be.fulfilled;
            });

            it('when contribution will equate weiRaised to funding goal', async function () {
                await increaseTimeTo(this.startTime);

                await this.crowdsale.changePrivateContribution(ether(37996.1), {from: owner});
                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.fulfilled;
                await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.fulfilled;
            });
        });

        describe('should not accept payments', function () {
            it('when crowdsale is inactive', async function () {
                await increaseTimeTo(this.prefundStart + duration.seconds(1));

                await this.crowdsale.stopCrowdsale({from: owner});
                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.rejected;
                await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.rejected;
            });

            it('when contributor is not whitelisted', async function () {
                await increaseTimeTo(this.prefundStart + duration.seconds(1));
                await this.crowdsale.sendTransaction({value: value, from: unauthorized}).should.be.rejected;
                await this.crowdsale.buyTokens(unauthorized, { value: value, from: unauthorized }).should.be.rejected;
            });

            it('when contribution is below minimum amount during pre-fund period', async function () {
                await increaseTimeTo(this.prefundStart + duration.seconds(1));
                await this.crowdsale.sendTransaction({value: belowPrefundMinimumValue, from: authorized}).should.be.rejected;
                await this.crowdsale.buyTokens(authorized, { value: belowPrefundMinimumValue, from: authorized }).should.be.rejected;
            });

            it('when contribution is below minimum amount during funding period', async function () {
                await increaseTimeTo(this.startTime + duration.seconds(1));
                await this.crowdsale.sendTransaction({value: belowMinimumValue, from: authorized}).should.be.rejected;
                await this.crowdsale.buyTokens(authorized, { value: belowMinimumValue, from: authorized }).should.be.rejected;
            });

            it('when contributor is different from beneficiary', async function () {
                await increaseTimeTo(this.prefundStart + duration.seconds(1));
                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.fulfilled;
                await this.crowdsale.buyTokens(anotherAuthorized, { value: belowMinimumValue, from: authorized }).should.be.rejected;
            });

            it('when contribution is before start of prefund', async function () {
                await increaseTimeTo(this.deployTime + duration.seconds(1));
                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.rejected;
                await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.rejected;
            });

            it('when contribution is after end time', async function () {
                await increaseTimeTo(this.endTime + duration.seconds(1));
                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.rejected;
                await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.rejected;
            });

            it('when contribution will exceed funding goal', async function () {
                await increaseTimeTo(this.prefundStart + duration.seconds(1));

                await this.crowdsale.changePrivateContribution(ether(37999), {from: owner});
                await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.rejected;
                await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.rejected;
            });
        });
    });

    describe('high level contribution process', function() {
        it('prefund contribution, tokens delivered', async function () {
            await increaseTimeTo(this.prefundStart);

            await this.crowdsale.sendTransaction({value: value, from: authorized}).should.be.fulfilled;
            await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.fulfilled;

            await this.token.transfer(this.crowdsale.address, ether(100000), {from: owner});
            await this.crowdsale.enableTokenRelease({from: owner});
            await this.crowdsale.releaseTokens([authorized], {from: owner});
            let balance = await this.token.balanceOf(authorized);
            let expectedValue = value * 12000 * 2;
            balance.should.be.bignumber.equal(expectedValue);
        });

        it('funding contribution, tokens delivered', async function () {
            await increaseTimeTo(this.startTime + duration.seconds(1));

            await this.crowdsale.sendTransaction({value: value, from: anotherAuthorized}).should.be.fulfilled;
            await this.crowdsale.buyTokens(anotherAuthorized, { value: value, from: anotherAuthorized }).should.be.fulfilled;

            await this.token.transfer(this.crowdsale.address, ether(100000), {from: owner});
            await this.crowdsale.enableTokenRelease({from: owner});
            await this.crowdsale.releaseTokens([anotherAuthorized], {from: owner});
            let balance = await this.token.balanceOf(anotherAuthorized);
            let expectedValue = value * 11500 * 2;
            balance.should.be.bignumber.equal(expectedValue);
        });

        it('tokens should not deliver when there is lack of tokens', async function () {
            await increaseTimeTo(this.startTime);

            await this.crowdsale.sendTransaction({value: value, from: authorized});
            await this.crowdsale.buyTokens(authorized, { value: value, from: authorized });
            await this.crowdsale.enableTokenRelease({from: owner});
            let tokenValue = value * 12000 * 2;
            await this.token.transfer(this.crowdsale.address, (value - 1), {from: owner});
            await this.crowdsale.releaseTokens([authorized], {from: owner}).should.be.rejected;
        });
    });

    describe('bonus structure', function () {
         it('during prefund period is 12000', async function () {
             await increaseTimeTo(this.prefundStart);
             let rate = await this.crowdsale.getRate();
             assert.equal(rate, 12000);
         });

         it('during day 1 is 11500', async function () {
             await increaseTimeTo(this.startTime + duration.seconds(1));
             let rate = await this.crowdsale.getRate();
             assert.equal(rate, 11500);
         });

         it('during day 2 - 3 is 11200', async function () {
             await increaseTimeTo(this.startTime + duration.days(1) + duration.seconds(1));
             let rate = await this.crowdsale.getRate();
             assert.equal(rate, 11200);
         });

         it('during day 4 - 7 is 10800', async function () {
             await increaseTimeTo(this.startTime + duration.days(3) + duration.seconds(1));
             let rate = await this.crowdsale.getRate();
             assert.equal(rate, 10800);
         });

         it('during week 2 is 10400', async function () {
             await increaseTimeTo(this.startTime + duration.weeks(1) + duration.days(1));
             let rate = await this.crowdsale.getRate();
             assert.equal(rate, 10400);
         });

         it('during week 3 is 10200', async function () {
             await increaseTimeTo(this.startTime + duration.weeks(2) + duration.days(1));
             let rate = await this.crowdsale.getRate();
             assert.equal(rate, 10200);
         });

         it('during week 4 is 10000', async function () {
             await increaseTimeTo(this.startTime + duration.weeks(3) + duration.days(1));
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

        it('only owner can enable token release', async function () {
            await this.crowdsale.enableTokenRelease({from: owner}).should.be.fulfilled;

            //enabling token release requires it to be disabled first
            await this.crowdsale.disableTokenRelease({from: owner}).should.be.fulfilled;
            await this.crowdsale.enableTokenRelease({from: authorized}).should.be.rejected;
        });

        it('only owner can disable token release', async function () {
            //disabling token release requires it to be enabled first
            await this.crowdsale.enableTokenRelease({from: owner}).should.be.fulfilled;
            await this.crowdsale.disableTokenRelease({from: owner}).should.be.fulfilled;

            //disabling token release requires it to be enabled first
            await this.crowdsale.enableTokenRelease({from: owner}).should.be.fulfilled;
            await this.crowdsale.disableTokenRelease({from: authorized}).should.be.rejected;
        });
    });

    describe('constructor parameters', function () {
        describe('should not initialize', function () {

            it('when wallet address is 0x0', async function () {
                try{
                    this.token = await GStarToken.new({from: owner});
                    this.crowdsale = await GStarCrowdsale.new(
                        this.prefundStart,
                        this.startTime,
                        this.endTime,
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

            it('when start time is before prefund start', async function () {
                try{
                    this.token = await GStarToken.new({from: owner});
                    this.crowdsale = await GStarCrowdsale.new(
                        this.startTime,
                        this.prefundStart,
                        this.endTime,
                        rate,
                        wallet,
                        this.token.address,
                        {from: owner}
                    );
                } catch(error) {
                    return utils.ensureException(error);
                }
                assert(false, "did not throw when start time is before prefund");
            });

            it('when end time is before start time', async function () {
                try{
                    this.token = await GStarToken.new({from: owner});
                    this.crowdsale = await GStarCrowdsale.new(
                        this.prefundStart,
                        this.endTime,
                        this.startTime,
                        rate,
                        wallet,
                        this.token.address,
                        {from: owner}
                    );
                } catch(error) {
                    return utils.ensureException(error);
                }
                assert(false, "did not throw when end time is before start time");
            });

            it('when token address is 0x0', async function () {
                try{
                    this.token = await GStarToken.new({from: owner});
                    this.crowdsale = await GStarCrowdsale.new(
                        this.prefundStart,
                        this.startTime,
                        this.endTime,
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
                        this.prefundStart,
                        this.startTime,
                        this.endTime,
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

            it('when crowdsale is shorter than 4 weeks', async function () {
                try{
                    this.token = await GStarToken.new({from: owner});
                    this.crowdsale = await GStarCrowdsale.new(
                        this.prefundStart,
                        this.startTime,
                        this.endTime - duration.days(1),
                        rate,
                        wallet,
                        this.token.address,
                        {from: owner}
                    );
                } catch(error) {
                    return utils.ensureException(error);
                }
                assert(false, "did not throw when crowdsale is shorter than 4 weeks");
            });
        });

    });
});
