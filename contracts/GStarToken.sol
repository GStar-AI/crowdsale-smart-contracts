pragma solidity ^0.4.18;

import "./math/SafeMath.sol";
import "./ownership/Ownable.sol";
import "./token/ERC20/StandardToken.sol";

contract GStarToken is StandardToken, Ownable {
    using SafeMath for uint256;

    string public constant name = "GSTAR Token";
    string public constant symbol = "GSTAR";
    uint8 public constant decimals = 18;

    uint256 public constant INITIAL_SUPPLY = 1600000000 * ((10 ** uint256(decimals)));
    uint256 public currentTotalSupply = 0;

    event Burn(address indexed burner, uint256 value);


    /**
    * @dev Constructor that gives msg.sender all of existing tokens.
    */
    function GStarToken() public {
        owner = msg.sender;
        totalSupply_ = INITIAL_SUPPLY;
        balances[owner] = INITIAL_SUPPLY;
        currentTotalSupply = INITIAL_SUPPLY;
        emit Transfer(address(0), owner, INITIAL_SUPPLY);
    }

    /**
    * @dev Burns a specific amount of tokens.
    * @param value The amount of token to be burned.
    */
    function burn(uint256 value) public onlyOwner {
        require(value <= balances[msg.sender]);

        address burner = msg.sender;
        balances[burner] = balances[burner].sub(value);
        currentTotalSupply = currentTotalSupply.sub(value);
        emit Burn(burner, value);
    }
}
