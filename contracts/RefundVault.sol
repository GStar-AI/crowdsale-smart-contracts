pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";

interface GStarToken {
  function transfer(address to, uint256 value) public returns (bool);
}

/**
 * @title RefundVault
 * @dev This contract is used for storing funds while a crowdsale
 * is in progress. Supports refunding the money if crowdsale fails,
 * and forwarding it if crowdsale is successful.
 */
contract RefundVault is Ownable {
  using SafeMath for uint256;

  enum State { Active, Refunding, Closed }

  GStarToken public gStarToken;

  mapping (address => bool) public whitelist;
  mapping (address => uint256) public depositedEther;
  mapping (address => uint256) public depositedTokens;
  address public wallet;
  State public state;

  event Closed();
  event RefundsEnabled();
  event Refunded(address indexed beneficiary, uint256 weiAmount);
  event TokensClaimed(address investor, uint256 tokensWeiAmount);
  event BulkWhitelistAndReleaseTokens(address[] beneficiaries);
  event Whitelisted(address beneficiary);

  /**
   * @param _wallet Vault address
   */
  function RefundVault(address _wallet, address deployedGStar) public {
    require(_wallet != address(0));
    wallet = _wallet;
    state = State.Active;
    gStarToken = GStarToken(deployedGStar);
  }

  /**
   * @param investor Investor address
   */
  function deposit(address investor, uint256 tokensWeiAmount) onlyOwner public payable {
    require(state == State.Active);
    depositedTokens[investor] = depositedTokens[investor].add(tokensWeiAmount);
    depositedEther[investor] = depositedEther[investor].add(msg.value);
  }

  function close() onlyOwner public {
    require(state == State.Active);
    state = State.Closed;
    Closed();
    wallet.transfer(this.balance);
  }

  function enableRefunds() onlyOwner public {
    require(state == State.Active);
    state = State.Refunding;
    RefundsEnabled();
  }

  /**
   * @param investor Investor address
   */
  function refund(address investor) onlyOwner public {
    require(state == State.Refunding);
    require(depositedTokens[investor] > 0);
    require(depositedEther[investor] > 0);

    uint256 depositedEtherValue = depositedEther[investor];
    depositedEther[investor] = 0;
    depositedTokens[investor] = 0;

    investor.transfer(depositedEtherValue);

    Refunded(investor, depositedEtherValue);
  }

  function claimTokens(address investor) onlyOwner public {
    require(depositedTokens[investor] > 0);
    require(depositedEther[investor] > 0);
    require(whitelist[investor]);

    uint256 tokensAmount = depositedTokens[investor];
    depositedTokens[investor] = 0;
    depositedEther[investor] = 0;

    gStarToken.transfer(investor, tokensAmount);
    TokensClaimed(investor, tokensAmount);
  }

  function addToWhiteList(address beneficiary) external onlyOwner {
    whitelist[beneficiary] = true;
    Whitelisted(beneficiary);
  }

  function addManyToWhitelist(address[] beneficiaries) external onlyOwner {
    for (uint256 i = 0; i < beneficiaries.length; i++) {
      whitelist[beneficiaries[i]] = true;
      Whitelisted(beneficiaries[i]);
    }
  }

  function whitelistAndReleaseTokens(address[] beneficiaries) external onlyOwner {
    for (uint256 i = 0; i < beneficiaries.length; i++) {
      address currentBeneficiary = beneficiaries[i];
      whitelist[currentBeneficiary] = true;
      Whitelisted(currentBeneficiary);

      if(depositedTokens[currentBeneficiary] > 0 && depositedEther[currentBeneficiary] > 0) {
        uint256 tokensAmount = depositedTokens[currentBeneficiary];
        depositedTokens[currentBeneficiary] = 0;
        depositedEther[currentBeneficiary] = 0;

        gStarToken.transfer(currentBeneficiary, tokensAmount);
      }
    }
  }

  function removeFromWhitelist(address beneficiary) external onlyOwner {
    whitelist[beneficiary] = false;
  }

}
