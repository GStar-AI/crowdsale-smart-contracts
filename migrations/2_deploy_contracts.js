var GStarToken = artifacts.require("./GStarToken");
var GStarCrowdsale = artifacts.require("./GStarCrowdsale")

module.exports = function(deployer) {
  deployer.deploy(GStarToken).then(function() {
    return deployer.deploy(GStarCrowdsale, GStarToken.address)
  });
};
