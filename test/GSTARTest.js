import decodeLogs from './helpers/decodeLogs';
const GStarToken = artifacts.require('GStarToken.sol');
const utils = require('./helpers/Utils');

contract('GStarToken', accounts => {
  let token;
  const creator = accounts[1];

  beforeEach(async function () {
    token = await GStarToken.new({ from: creator });
  });

  it('has a name', async function () {
    const name = await token.name();
    assert.equal(name, 'GSTAR Token');
  });

  it('has a symbol', async function () {
    const symbol = await token.symbol();
    assert.equal(symbol, 'GSTAR');
  });

  it('has 18 decimals', async function () {
    const decimals = await token.decimals();
    assert(decimals.eq(18));
  });

  it('assigns the initial total supply to the creator', async function () {
    const totalSupply = await token.totalSupply();
    const creatorBalance = await token.balanceOf(creator);

    assert(creatorBalance.eq(totalSupply));

    const receipt = web3.eth.getTransactionReceipt(token.transactionHash);
    const logs = decodeLogs(receipt.logs, GStarToken, token.address);
    assert.equal(logs.length, 1);
    assert.equal(logs[0].event, 'Transfer');
    assert.equal(logs[0].args.from.valueOf(), 0x0);
    assert.equal(logs[0].args.to.valueOf(), creator);
    assert(logs[0].args.value.eq(totalSupply));
  });

  it('should throw when a non-owner attempts to burn tokens', async () => {
    try {
      await token.burn(10000, {
        from: accounts[2]
      });
    } catch (error) {
      return utils.ensureException(error);
    }
  });

  it('burns the stated amount from the owners balance successfully', async function () {
    let burnAmount = 10000;
    let expectedBalance = await token.balanceOf.call(creator) - burnAmount;
    await token.burn(burnAmount, { from: creator});
    let afterBalance = await token.balanceOf.call(creator);
    assert.equal(expectedBalance, afterBalance);
  });
});
