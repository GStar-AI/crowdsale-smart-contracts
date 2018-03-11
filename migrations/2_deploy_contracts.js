var GStarToken = artifacts.require("./contracts/GStarToken");
var GStarCrowdsale = artifacts.require("./contracts/GStarCrowdsale");
var GSTARAirdrop = artifacts.require("./contracts/GSTARAirdrop");

module.exports = function(deployer) {

    const MIN = 60;
    const HOUR = 60 * MIN;
    const DAY =  24 * HOUR;
    const WEEK = 7 * DAY;

    const rate = new web3.BigNumber(10000);
    const wallet = web3.eth.accounts[0];

    const prefundStart = web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    const startTime = prefundStart + WEEK * 2;
    const endTime = startTime + WEEK * 4;

/*
    deployer.deploy(GStarToken, {from: "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE"}).then(function() {
          deployer.deploy(GSTARAirdrop, GStarToken.address, {from: "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE"});
          return deployer.deploy(GStarCrowdsale, rate, wallet, GStarToken.address, {from: "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE"});
      });
  };
*/


    //for testing, do not indicate address
    deployer.deploy(GStarToken).then(function() {
          deployer.deploy(GSTARAirdrop, GStarToken.address);
          return deployer.deploy(GStarCrowdsale, prefundStart, startTime, endTime, rate, wallet, GStarToken.address);
      });
  };
