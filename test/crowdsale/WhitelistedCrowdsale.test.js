import ether from '../helpers/ether';

const BigNumber = web3.BigNumber;
const utils = require('../helpers/Utils');

require('chai')
  .use(require('chai-as-promised'))
  .should();

const GStarCrowdsale = artifacts.require('GStarCrowdsale');
const GStarToken = artifacts.require('GStarToken');

contract('GStarCrowdsale', function ([_, wallet, accounts]) {
    let token;
    let crowdsale;
    const rate = 10000;
    const value = ether(10);
    const tokenSupply = ether(800000000);
    let owner = web3.eth.accounts[0];
    let authorized = web3.eth.accounts[1];
    let unauthorized = web3.eth.accounts[2];
    let anotherAuthorized = web3.eth.accounts[3];

  describe('single user whitelisting', function () {
    beforeEach(async function () {
      this.token = await GStarToken.new();
      this.crowdsale = await GStarCrowdsale.new(rate, wallet, this.token.address, { from: owner });
      await this.crowdsale.addToWhitelist(authorized, {from: owner});
      await this.crowdsale.startCrowdsale({from: owner });
    });

    describe('accepting payments', function () {
      it('should accept payments to whitelisted (from whichever buyers)', async function () {
        await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.fulfilled;
        await this.crowdsale.buyTokens(authorized, { value: value, from: unauthorized }).should.be.rejected;
      });

      it('should reject payments to not whitelisted (from whichever buyers)', async function () {
        await this.crowdsale.send(value).should.be.rejected;
        await this.crowdsale.buyTokens(unauthorized, { value: value, from: unauthorized }).should.be.rejected;
        await this.crowdsale.buyTokens(unauthorized, { value: value, from: authorized }).should.be.rejected;
      });

      it('should reject payments to addresses removed from whitelist', async function () {
        await this.crowdsale.removeFromWhitelist(authorized);
        await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.rejected;
      });
    });

    describe('reporting whitelisted', function () {
      it('should correctly report whitelisted addresses', async function () {
        let isAuthorized = await this.crowdsale.whitelist(authorized);
        isAuthorized.should.equal(true);
        let isntAuthorized = await this.crowdsale.whitelist(unauthorized);
        isntAuthorized.should.equal(false);
      });
    });
  });

  describe('many user whitelisting', function () {
    beforeEach(async function () {
      this.token = await GStarToken.new();
      this.crowdsale = await GStarCrowdsale.new(rate, wallet, this.token.address);
      await this.crowdsale.addManyToWhitelist([authorized, anotherAuthorized], {from: owner});
      await this.crowdsale.startCrowdsale({from: owner });
    });

    describe('accepting payments', function () {
      it('should accept payments to whitelisted (from whichever buyers)', async function () {
        await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.fulfilled;
        await this.crowdsale.buyTokens(authorized, { value: value, from: unauthorized }).should.be.rejected;
        await this.crowdsale.buyTokens(anotherAuthorized, { value: value, from: authorized }).should.be.rejected;
        await this.crowdsale.buyTokens(anotherAuthorized, { value: value, from: unauthorized }).should.be.rejected;
      });

      it('should reject payments to not whitelisted (with whichever buyers)', async function () {
        await this.crowdsale.send(value).should.be.rejected;
        await this.crowdsale.buyTokens(unauthorized, { value: value, from: unauthorized }).should.be.rejected;
        await this.crowdsale.buyTokens(unauthorized, { value: value, from: authorized }).should.be.rejected;
      });

      it('should reject payments to addresses removed from whitelist', async function () {
        await this.crowdsale.removeFromWhitelist(anotherAuthorized);
        await this.crowdsale.buyTokens(authorized, { value: value, from: authorized }).should.be.fulfilled;
        await this.crowdsale.buyTokens(anotherAuthorized, { value: value, from: authorized }).should.be.rejected;
      });
    });

    describe('reporting whitelisted', function () {
      it('should correctly report whitelisted addresses', async function () {
        let isAuthorized = await this.crowdsale.whitelist(authorized);
        isAuthorized.should.equal(true);
        let isAnotherAuthorized = await this.crowdsale.whitelist(anotherAuthorized);
        isAnotherAuthorized.should.equal(true);
        let isntAuthorized = await this.crowdsale.whitelist(unauthorized);
        isntAuthorized.should.equal(false);
      });
    });
  });
});
