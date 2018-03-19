pragma solidity ^0.4.19;

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
    event Close();

    function GSTARAirdrop(address deployedGStar) public {
        require(deployedGStar != address(0));

        gStarToken = GStarToken(deployedGStar);
    }

    function drop(address[] beneficiaries, uint256 tokensAmountEachReceives) external onlyOwner {
        require(beneficiaries.length > 0);
        require(tokensAmountEachReceives > 0);
        uint256 tokenWeiAmountEachReceives = tokensAmountEachReceives.mul(decimals);

        uint256 totalAmountRequired = beneficiaries.length.mul(tokenWeiAmountEachReceives);

        require(gStarToken.balanceOf(address(this)) >= totalAmountRequired);

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            gStarToken.transfer(beneficiaries[i], tokenWeiAmountEachReceives);
        }
        Dropped(beneficiaries, tokensAmountEachReceives);
    }

    function close() external onlyOwner {
        gStarToken.transfer(owner, gStarToken.balanceOf(address(this)));
        Close();
    }
}
