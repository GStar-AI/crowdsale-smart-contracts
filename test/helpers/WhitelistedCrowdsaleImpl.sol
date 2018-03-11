pragma solidity ^0.4.18;

import "../../contracts/token/ERC20/ERC20.sol";
import "../../contracts/crowdsale/validation/WhitelistedCrowdsale.sol";


contract WhitelistedCrowdsaleImpl is WhitelistedCrowdsale {

  function WhitelistedCrowdsaleImpl (
    uint256 _rate,
    address _wallet,
    ERC20 _token
  )
    public
    Crowdsale(_rate, _wallet, _token)
  {
  }

}
