pragma solidity ^0.4.18;

import "./math/SafeMath.sol";
import "./ownership/Ownable.sol";


interface GStarToken {
    function transfer(address to, uint256 value) public returns (bool);
    function balanceOf(address who) public view returns (uint256);
}


contract GSTARAirdrop is Ownable {
    using SafeMath for uint256;

    GStarToken public gStarToken;
    uint256 public decimals = 10**18;

    event Dropped(address[] beneficiaries, uint256 tokensAmountEachReceives);

    function GSTARAirdrop(address deployedGStar) public {
        gStarToken = GStarToken(deployedGStar);
    }

    function drop(address[] beneficiaries, uint256 tokensAmountEachReceives) public onlyOwner {
        uint256 tokenWeiAmountEachReceives = tokensAmountEachReceives.mul(decimals);
        uint256 totalAmountRequired = beneficiaries.length.mul(tokenWeiAmountEachReceives);
        require(gStarToken.balanceOf(address(this)) >= totalAmountRequired);

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            gStarToken.transfer(beneficiaries[i], tokenWeiAmountEachReceives);
        }
        Dropped(beneficiaries, tokensAmountEachReceives);
    }
}
