var GStarToken = artifacts.require("./contracts/GStarToken");
var GStarCrowdsale = artifacts.require("./contracts/GStarCrowdsale");

module.exports = function(deployer) {

    const MIN = 60;
    const HOUR = 60 * MIN;
    const DAY =  24 * HOUR;
    const WEEK = 7 * DAY;

    //REMEMBER TO CHANGE ADDRESS BEFORE ACTUAL DEPLOYMENT ON MAINNET!!!
    const rate = new web3.BigNumber(10000);
    const wallet = "0xC05207E395De707e95052e89c84A5817A6938827";
    const owner = "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE";

    //REMEMBER TO CHANGE TIME!!!!
    //CURRENTLY THE CROWDSALE STARS 2 WEEKS AFTER!
    const currentTime = web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    const startTime = currentTime + WEEK * 2;


    //deployer.deploy(GStarCrowdsale, rate, wallet, GStarToken.address, {from: owner});
    deployer.deploy(GStarCrowdsale, rate, wallet, GStarToken.address);

};
