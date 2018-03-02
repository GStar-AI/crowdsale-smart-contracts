pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "./RefundVault.sol";
import "./GStarToken.sol";

/**
 * @title GStarCrowdsale
 * @dev This contract manages the crowdsale of GStar Tokens.
 * The crowdsale will involve seven key timings - Start time, end time,
 * and the start time of each five phases. In each phase, token buyers
 * will receive different bonuses - The earlier the purchase, the larger
 * the bonuses.
 * Funds collected are forwarded to a wallet as they arrive.
 * There is only one owner at any one time. The owner can stop or start
 * the crowdsale at anytime. In case unforeseen demand, the owner can
 * choose to raise the fundingGoal as required.
 */
contract GStarCrowdsale is Ownable {
  using SafeMath for uint256;

  // The address of the GStar Token contract deployed.
  GStarToken public gStarToken;
  RefundVault public refundVault;

  // Start and end timestamps where investments are allowed (both inclusive)
  // All timestamps are expressed in seconds instead of block number.
  uint256 public startTime = 1518500261;
  uint256 public phaseOne = 1518600261;
  uint256 public phaseTwo = 1518700261;
  uint256 public phaseThree = 1518800261;
  uint256 public phaseFour = 1518900261;
  uint256 public phaseFive = 1519500261;
  uint256 public phaseSix = 1519600261;
  uint256 public phaseSeven = 1519700261;
  uint256 public endTime = 1519800261;

  // Important addresses for this crowdsale.
  // Note that the owner only refers to owner of the crowdsale,
  // not the owner of the GStar Token.
  address public owner;
  address public ETH_WALLET = 0x9A1C6fA66DbaEA367e21403609628a40Cf345b6e; //ETH will be forwarded to this address.

  // The base rate the buyer gets for each ETH invested.
  // This rate is exclusive of any bonuses.
  uint256 public GST_PER_ETH = 10000;

  // Parameters for this crowdsale.
  uint256 public MINIMUM_PURCHASE_AMOUNT_IN_WEI = 10**17; // the minimum of ETH that buyer can purchase is 0.1ETH
  uint256 public PRE_ICO_MINIMUM_PURCHASE_AMOUNT_IN_WEI = 10**18; // the minimum of ETH that buyer can purchase during pre-ICO is 1ETH
  uint256 public fundingGoal = 1 * (10**18); //expressed in amount of Ether in Wei units
  uint256 public tokensRaisedInWei = 0;
  uint256 public etherRaisedInWei = 0;
  bool fundingGoalReached = false;
  bool crowdsaleActive = false;


/*
  mapping (address -> bool) registered;
  mapping(address -> uint256) etherContributed;
  mapping(address -> uint256) tokensReward;
*/
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event GoalReached(uint256 totalAmountRaised);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event FundingGoalRaised(uint256 newFundingGoal);
  event ETHWalletAddressChanged(address newETHWallet);


  /**
  * @dev Constructor function. Checks validity of the time entered and sets owner.
  */
  function GStarCrowdsale(address deployedGStar) public {
    require(startTime < phaseOne);
    require(phaseOne < phaseTwo);
    require(phaseTwo < phaseThree);
    require(phaseThree < phaseFour);
    require(phaseFour < phaseFive);
    require(phaseFive < phaseSix);
    require(phaseSix < phaseSeven);
    require(phaseSeven < endTime);

    require(fundingGoal > 0);

    owner = msg.sender;
    gStarToken = GStarToken(deployedGStar);
    refundVault = new RefundVault(ETH_WALLET, deployedGStar);
  }

  /**
  * @dev Fallback function can be used to buy tokens when crowdsale is active.
  */
  function () public payable {
    require(crowdsaleActive);
    buyTokens(msg.sender);
  }

  /**
  * @dev Actual buy tokens function. Buyers can choose to buy for another person by
  * calling this contract directly. However, that will not be our main mode of token sale.
  * @param beneficiary The address that receives the tokens purchased.
  */
  function buyTokens(address beneficiary) public payable {
    require(beneficiary != address(0));
    require(msg.sender == beneficiary);
    require(validPurchase());

    // throws if this purchase exceed funding goal
    uint256 weiAmount = msg.value;
    require(weiAmount.add(etherRaisedInWei) <= fundingGoal);

    // calculate total token amount purchased. bonus included
    uint256 tokens = getTokenAmount(weiAmount);

    // update state
    etherRaisedInWei = etherRaisedInWei.add(weiAmount);
    tokensRaisedInWei = tokensRaisedInWei.add(tokens);

    // forward ETH amount to RefundVault
    refundVault.deposit.value(msg.value)(msg.sender, tokens);

    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

    /*
    // After purchase is succesful, the contract records the details
    uint256 previousContribution = etherContributed[msg.sender];
    etherContributed[msg.sender] = previousContribution.add(weiAmount);
    uint256 previousTokenAmount = tokensReward[beneficiary];
    tokensReward[beneficiary] = previousTokenAmount.add(tokens);
    */

    // checks and update fundingGoal
    isFundingGoalReached();
  }

  /**
  * @dev Calculates the bonuses and total token amount buyer receives.
  *
  * @param weiAmount The ETH amount buyer sent to this contract.
  * @return The total token amount buyer will receive.
  */
  function getTokenAmount(uint256 weiAmount) internal view returns(uint256) {

    uint256 baseAmount = weiAmount.mul(GST_PER_ETH);
    uint256 onePercentOfBaseAmount = baseAmount.div(100); //used for calculating bonus
    uint256 bonusAmount = 0;

    //calculate bonus based on phases
    if(now >= startTime && now < phaseOne) {
      //Prefund period, 25 percent bonus
      bonusAmount = onePercentOfBaseAmount.mul(25);

    } else if(now >= phaseOne && now < phaseTwo) {
      //Phase One, 20 percent bonus
      bonusAmount = onePercentOfBaseAmount.mul(20);

    } else if(now >= phaseTwo && now < phaseThree) {
      //Phase Two, 15 percent bonus
      bonusAmount = onePercentOfBaseAmount.mul(16);

    } else if(now >= phaseThree && now < phaseFour) {
      //Phase Three, 10 percent bonus
      bonusAmount = onePercentOfBaseAmount.mul(12);

    } else if(now >= phaseFour && now < phaseFive) {
      //Phase Four, 5 percent bonus
      bonusAmount = onePercentOfBaseAmount.mul(8);

    } else if(now >= phaseFive && now < phaseSix) {
      //Phase Four, 5 percent bonus
      bonusAmount = onePercentOfBaseAmount.mul(4);

    } else if(now >= phaseSix && now < phaseSeven) {
      //Phase Four, 5 percent bonus
      bonusAmount = onePercentOfBaseAmount.mul(2);

    } else if(now >= phaseSeven && now < endTime) {
      //Phase Five, no bonus
      bonusAmount = 0;
    }

    uint256 totalPurchaseAmount = baseAmount.add(bonusAmount);
    return totalPurchaseAmount;
  }

  /**
  * @dev Checks and updates fundingGoal status.
  * @return Returns true if fundingGoal is reached.
  */
  function isFundingGoalReached() internal returns(bool) {
    if(etherRaisedInWei >= fundingGoal){
      fundingGoalReached = true;
      return true;

    } else {
      return false;
    }
  }

  /**
  * @dev Displays if crowdsale is active.
  * @return Returns true if crowdsale is active.
  */
  function isCrowdsaleActive() public view returns (bool) {
    return crowdsaleActive;
  }

  /**
  * @dev Displays the amount of token remaining in this contract.
  * @return Returns amount of tokens, in wei unit, this contract owns.
  */
  function remainingTokens() public view returns (uint256) {
    return gStarToken.balanceOf(this);
  }


  /**
  * @dev Checks if purchase is made within crowdsale period.
  * Also checks if purchase is non-zero.
  * @return Returns true if purchase meets both requirements.
  */
  function validPurchase() internal view returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool atLeastMinimumAmount = msg.value >= MINIMUM_PURCHASE_AMOUNT_IN_WEI;

    if(now >= startTime && now < phaseOne) {
      atLeastMinimumAmount = msg.value >= PRE_ICO_MINIMUM_PURCHASE_AMOUNT_IN_WEI;
    }
    return withinPeriod && atLeastMinimumAmount && crowdsaleActive;
  }

  /**
  * @dev Allows owner to start/unpause crowdsale.
  */
  function startCrowdsale() public onlyOwner {
    crowdsaleActive = true;
  }

  /**
  * @dev Allows owner to stop/pause crowdsale.
  */
  function stopCrowdsale() public onlyOwner {
    crowdsaleActive = false;
  }


  /**
   * @dev Allows the current owner to change where ETH is stored.
   * @param newWalletAddress The new address to forward funds to.
   */
  function changeETHWallet(address newWalletAddress) public onlyOwner {
    require(newWalletAddress != address(0));
    ETH_WALLET = newWalletAddress;
    ETHWalletAddressChanged(ETH_WALLET);
  }

  function claimTokens() public {
    refundVault.claimTokens(msg.sender);
  }

  function claimRefund() public {
    refundVault.refund(msg.sender);
  }

  function enableRefund() public onlyOwner {
    refundVault.enableRefunds();
  }

  function closeRefund() public onlyOwner {
    refundVault.close();
  }

  function addToWhitelist(address beneficiary) public onlyOwner {
    refundVault.addToWhiteList(beneficiary);
  }

  function removeFromWhitelist(address beneficiary) public onlyOwner {
    refundVault.removeFromWhitelist(beneficiary);
  }

  function addManyToWhitelist(address[] beneficiaries) public onlyOwner {
    refundVault.addManyToWhitelist(beneficiaries);
  }

  function whitelistAndReleaseTokens(address[] beneficiaries) public onlyOwner {
    refundVault.whitelistAndReleaseTokens(beneficiaries);
  }

}
