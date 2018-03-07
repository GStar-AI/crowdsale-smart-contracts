var GStarToken = artifacts.require("./contracts/GStarToken");
var GStarCrowdsale = artifacts.require("./contracts/GStarCrowdsale");

module.exports = function(deployer) {

    const rate = new web3.BigNumber(10000);
    const wallet = web3.eth.accounts[0];

  deployer.deploy(GStarToken, {from: "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE"}).then(function() {
        return deployer.deploy(GStarCrowdsale, rate, wallet, GStarToken.address, {from: "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE"});
    });
};
