var GStarToken = artifacts.require("./contracts/GStarToken");
var GSTARAirdrop = artifacts.require("./contracts/GSTARAirdrop");

module.exports = function(deployer) {

    const owner = "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE";

    //deployer.deploy(GSTARAirdrop, GStarToken.address, {from: owner});
    deployer.deploy(GSTARAirdrop, GStarToken.address);

};