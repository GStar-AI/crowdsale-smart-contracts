var GStarToken = artifacts.require("./contracts/GStarToken");
var GStarCrowdsale = artifacts.require("./contracts/GStarCrowdsale");
var RefundVault = artifacts.require("./contracts/RefundVault");

module.exports = function(deployer) {
  deployer.deploy(GStarToken, {from: "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE"}).then(function() {
    deployer.deploy(RefundVault, GStarToken.address, {from: "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE"}).then(function() {
        return deployer.deploy(GStarCrowdsale, GStarToken.address, RefundVault.address, {from: "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE"});
    });
  });
};
