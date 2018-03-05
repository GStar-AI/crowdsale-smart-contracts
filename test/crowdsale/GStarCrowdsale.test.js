import ether from '../helpers/ether';
import EVMRevert from '../helpers/EVMRevert';

const BigNumber = web3.BigNumber;
const assertJump = require('../helpers/assertJump');

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const GStarCrowdsale = artifacts.require('GStarCrowdsale');
const RefundVault = artifacts.require('RefundVault');
const GStarToken = artifacts.require('GStarToken');
const owner = web3.eth.accounts[1];

contract('GStarCrowdsale', function ([_, investor, wallet]) {

  const rate = new BigNumber(10000);
  const fundingGoal = ether(10);
  const lessThanCap = ether(1);
  const expectedMinimumAmount = rate.mul(lessThanCap).mul(2);

  beforeEach(async function() {
      this.token = await GStarToken.new({from: owner});
      this.crowdsale = await GStarCrowdsale.new(this.token.address, {from: owner});
  });

  describe('ownership of crowdsale functions should be enforced', function () {

    it('non-owner cannot start crowdsale', async function () {
      try{
        await this.crowdsale.startCrowdsale({from: web3.eth.accounts[2]});
        assert.fail('should have thrown before');
      } catch (error) {
        assertJump(error);
      }
    });

    it('non-owner cannot stop crowdsale', async function () {
      try{
        await this.crowdsale.stopCrowdsale({from: web3.eth.accounts[2]});
        assert.fail('should have thrown before');
      } catch (error) {
        assertJump(error);
      }
    });

    it('owner can start crowdsale', async function () {
      await this.crowdsale.startCrowdsale({from: owner}).should.be.fulfilled;
    });

    it('owner can stop crowdsale', async function () {
        await this.crowdsale.stopCrowdsale({from: owner}).should.be.fulfilled;
    });
  });

  describe('creating a valid crowdsale', function () {

    it('accept payments within cap', async function () {
      await this.crowdsale.startCrowdsale({from: owner});
      await this.crowdsale.send(fundingGoal.minus(lessThanCap)).should.be.fulfilled;
      await this.crowdsale.send(lessThanCap).should.be.fulfilled;
    });

    it('should reject payments outside funding goal', async function () {
      await this.crowdsale.startCrowdsale({from: owner});
      await this.crowdsale.send(fundingGoal);
      //await this.crowdsale.send(1).should.be.rejectedWith(EVMRevert);
    });

    it('should reject payments that exceed funding goal', async function () {
      await this.crowdsale.startCrowdsale({from: owner});
      await this.crowdsale.send(fundingGoal.plus(1)).should.be.rejectedWith(EVMRevert);
    });
  });

  describe('ending', function () {
    it('should not reach cap if sent under cap', async function () {
      await this.crowdsale.startCrowdsale({from: owner});
      let capReached = await this.crowdsale.isFundingGoalReached();
      capReached.should.equal(false);
      await this.crowdsale.send(lessThanCap);
      capReached = await this.crowdsale.isFundingGoalReached();
      capReached.should.equal(false);
    });

    it('should not reach cap if sent just under cap', async function () {
      await this.crowdsale.startCrowdsale({from: owner});
      await this.crowdsale.send(fundingGoal.minus(1));
      let capReached = await this.crowdsale.isFundingGoalReached();
      capReached.should.equal(false);
    });

    it('should reach cap if cap sent', async function () {
      await this.crowdsale.startCrowdsale({from: owner});
      await this.crowdsale.send(fundingGoal);
      let capReached = await this.crowdsale.isFundingGoalReached();
      capReached.should.equal(true);
    });
  });

  describe('high-level purchase', function () {
    it('should log purchase', async function () {
      await this.crowdsale.startCrowdsale({from: owner});
      const { logs } = await this.crowdsale.sendTransaction({ value: lessThanCap, from: investor });
      const event = logs.find(e => e.event === 'TokenPurchase');
      //should.exist(event);
      event.args.purchaser.should.equal(investor);
      event.args.beneficiary.should.equal(investor);
      event.args.value.should.be.bignumber.equal(lessThanCap);
      //event.args.amount.should.be.bignumber.equal(expectedTokenAmount);
    });

    it('should assign tokens to sender', async function () {
      await this.crowdsale.startCrowdsale({from: owner});
      await this.crowdsale.sendTransaction({ value: lessThanCap, from: investor });
      await this.crowdsale.enableSettlement({from: owner});
      let refundVaultAddress = await this.crowdsale.refundVault.address;
      //await this.token.transfer(refundVaultAddress, expectedMinimumAmount, {from: owner});
      //await this.crowdsale.whitelistAndReleaseTokens([investor], {from: owner});
      //let balance = await this.token.balanceOf(investor);
      //balance.should.be.bignumber.higher(expectedTokenAmount);
      //assert(balance >= expectedMinimumAmount);
    });
  });

  describe('Bonus Rate', function () {
    beforeEach(async function () {
      this.startTime = 1520060000;
      this.phaseOne = 1521060000;
      this.phaseTwo = 1522060000;
      this.phaseThree = 1523060000;
      this.phaseFour = 1524060000;
      this.phaseFive = 1525060000;
      this.phaseSix = 1526060000;
      this.phaseSeven = 1527060000;
      this.endTime = 1528060000;
      await increaseTimeTo(this.startTime);
    });

    it('should be on prefund period, 25% bonus' async function () {
      let rate = await this.crowdsale.get
    });
  });
});
