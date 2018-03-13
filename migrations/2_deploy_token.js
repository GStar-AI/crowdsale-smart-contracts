var GStarToken = artifacts.require("./contracts/GStarToken");

module.exports = function(deployer) {

    const owner = "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE";

    //deployer.deploy(GStarToken, {from: owner});
    deployer.deploy(GStarToken);
};
