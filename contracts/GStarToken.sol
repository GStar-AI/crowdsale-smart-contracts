pragma solidity ^0.4.18;

import './math/SafeMath.sol';
import './ownership/Ownable.sol';
import './token/ERC20/StandardToken.sol';

contract GStarToken is StandardToken, Ownable {
  using SafeMath for uint256;

  string public constant name = "GSTAR Token"; // solium-disable-line uppercase
  string public constant symbol = "GSTAR"; // solium-disable-line uppercase
  uint8 public constant decimals = 18; // solium-disable-line uppercase

  uint256 public constant INITIAL_SUPPLY = 1800000000 * (10 ** uint256(decimals));
  uint256 public current_total_supply = 0;

  event RaiseCap(address owner, uint256 SUPPLY_CAP);
  event Burn(address indexed burner, uint256 value);


  /**
   * @dev Constructor that gives msg.sender all of existing tokens.
   */
  function GStarToken() public {
    owner = msg.sender;
    totalSupply_ = INITIAL_SUPPLY;
    balances[owner] = INITIAL_SUPPLY;
    current_total_supply = INITIAL_SUPPLY;
    Transfer(address(0), owner, INITIAL_SUPPLY);
  }

  /**
   * @dev Burns a specific amount of tokens.
   * @param _value The amount of token to be burned.
   */
  function burn(uint256 _value) public onlyOwner {
    require(_value <= balances[msg.sender]);
    // no need to require value <= totalSupply, since that would imply the
    // sender's balance is greater than the totalSupply, which *should* be an assertion failure

    address burner = msg.sender;
    balances[burner] = balances[burner].sub(_value);
    current_total_supply = current_total_supply.sub(_value);
    Burn(burner, _value);
  }
}