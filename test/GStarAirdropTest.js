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

const GStarToken = artifacts.require('GStarToken');
const GSTARAirdrop = artifacts.require('GSTARAirdrop');

contract('GSTARAirdrop', function () {
    const dropAmount = 400;
    const supplyAmount = 20000;
    let owner = web3.eth.accounts[0];
    let firstReceiver = web3.eth.accounts[1];
    let secondReceiver = web3.eth.accounts[2];
    let thirdReceiver = web3.eth.accounts[3];

    beforeEach(async function () {
        this.token = await GStarToken.new({from: owner});
        this.airdrop = await GSTARAirdrop.new(this.token.address, {from: owner});
    });

    describe('close function', function () {

        it('transfers remaining tokens back to owner', async function () {
            await this.token.transfer(web3.eth.accounts[4], 1.6e27, {from: owner}); //owner transfers all tokens out
            await this.token.transfer(this.airdrop.address, ether(supplyAmount), {from: web3.eth.accounts[4]});
            let expected = ether(supplyAmount) - ether(dropAmount * 3);
            await this.airdrop.drop([firstReceiver, secondReceiver, thirdReceiver], dropAmount, {from: owner});
            await this.airdrop.close({from: owner});
            let afterBalance = await this.token.balanceOf(owner);

            afterBalance.should.be.bignumber.equal(expected);
        });
    });

    describe('drop sanity checks', function () {

        it('requires at least one beneficiary', async function () {
            await this.token.transfer(this.airdrop.address, ether(supplyAmount), {from: owner});
            await this.airdrop.drop([], dropAmount, {from: owner}).should.be.rejected;
        });

        it('requires non-zero token amount', async function () {
            await this.token.transfer(this.airdrop.address, ether(supplyAmount), {from: owner});
            await this.airdrop.drop([firstReceiver, secondReceiver, thirdReceiver], 0, {from: owner}).should.be.rejected;
        });

        it('should not execute drop when there is insufficient tokens for a single receiver', async function () {
            await this.airdrop.drop([firstReceiver], dropAmount, {from: owner}).should.be.rejected;
        });

        it('should not execute drop when there is insufficient tokens for multiple receivers', async function () {
            await this.token.transfer(this.airdrop.address, ether(dropAmount * 2), {from: owner});
            await this.airdrop.drop([firstReceiver, secondReceiver, thirdReceiver], dropAmount, {from: owner}).should.be.rejected;
        });
    });

    describe('high level drop process', function () {

        beforeEach(async function () {
            await this.token.transfer(this.airdrop.address, ether(supplyAmount), {from: owner});
        });

        it('successfully delivers tokens to one address', async function () {
            await this.airdrop.drop([firstReceiver], dropAmount, {from: owner}).should.be.fulfilled;
        });

        it('successfully delivers tokens to multiple addresses', async function () {
            await this.airdrop.drop([firstReceiver, secondReceiver, thirdReceiver], dropAmount, {from: owner}).should.be.fulfilled;
        });
    });

    describe('constructor parameters', function () {
        describe('should not initialize', function () {

            it('when token address is 0x0', async function () {
                try{
                    this.token = await GStarToken.new({from: owner});
                    this.airdrop = await GSTARAirdrop.new(0x0, {from: owner});
                } catch(error) {
                    return utils.ensureException(error);
                }
                assert(false, "did not throw when token address is invalid");
            });
        });
    });
});
