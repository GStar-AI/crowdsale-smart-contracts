pragma solidity ^0.4.18;

import "./math/SafeMath.sol";
import "./ownership/Ownable.sol";
import "./crowdsale/Crowdsale.sol";
import "./crowdsale/validation/WhitelistedCrowdsale.sol";

import "./GStarToken.sol";

/**
 * @title GStarCrowdsale
 * @dev This contract manages the crowdsale of GStar Tokens.
 * The crowdsale will involve eight key timings - Start time, end time,
 * and the start time of each six phases. In each phase, token buyers
 * will receive different bonuses - The earlier the purchase, the larger
 * the bonuses.
 * Funds collected are forwarded to a RefundVault as they arrive.
 * Buyers can claim their tokens or refund from this crowdsale contract,
 * which will then access the RefundVault contract.
 * There is only one owner at any one time. The owner can stop or start
 * the crowdsale at anytime.
 */
contract GStarCrowdsale is WhitelistedCrowdsale {
    using SafeMath for uint256;

    // Start and end timestamps where investments are allowed (both inclusive)
    // All timestamps are expressed in seconds instead of block number.
    uint256 public startTime = 1520060000;
    uint256 public phaseOne = 1521060000;
    uint256 public phaseTwo = 1522060000;
    uint256 public phaseThree = 1523060000;
    uint256 public phaseFour = 1524060000;
    uint256 public phaseFive = 1525060000;
    uint256 public phaseSix = 1526060000;
    uint256 public endTime = 1528060000;

    // Keeps track of contributors tokens
    mapping (address => uint256) public depositedTokens;

    // Minimum amount of ETH contribution during ICO and Pre-ICO period
    // Minimum of ETH contributed during ICO is 0.1ETH
    // Minimum of ETH contributed during pre-ICO is 1ETH
    uint256 public MINIMUM_PURCHASE_AMOUNT_IN_WEI = 10**17;
    uint256 public PRE_ICO_MINIMUM_PURCHASE_AMOUNT_IN_WEI = 10**18;

    // Total tokens raised so far, bonus inclusive
    uint256 public tokensWeiRaised = 0;

    //Funding goal is 38,000 ETH
    uint256 public fundingGoal = 10 ether;
    bool public fundingGoalReached = false;

    // Indicates if crowdsale is active
    bool public crowdsaleActive = false;

    // Indicates if tokens can be released
    bool public canTokenRelease = false;

    uint256 public tokensReleasedAmount = 0;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event GoalReached(uint256 totalEtherAmountRaised);
    event StartCrowdsale();
    event StopCrowdsale();
    event SettlementEnabled();
    event SettlementEnded();
    event TokenReleaseEnabled();
    event TokenReleaseDisabled();
    event ReleaseTokens(address[] _beneficiaries);
    event Close();

    /**
    * @dev Constructor. Checks validity of the time entered.
    */
    function GStarCrowdsale(uint256 _rate, address _wallet, GStarToken token) public
    Crowdsale(_rate, _wallet, token) {
        require(startTime < phaseOne);
        require(phaseOne < phaseTwo);
        require(phaseTwo < phaseThree);
        require(phaseThree < phaseFour);
        require(phaseFour < phaseFive);
        require(phaseFive < phaseSix);
        require(phaseSix < endTime);

        require(fundingGoal > 0);
    }

    /**
    * @dev Overrides _preValidatePurchase function in Crowdsale.
    * Requires purchase is made within crowdsale period.
    * Requires contributor to be the beneficiary.
    * Requires purchase value and address to be non-zero.
    * Requires amount not to exceed funding goal.
    * Requires purchase value to be higher or equal to minimum amount.
    * Requires contributor to be whitelisted.
    * The minimum purchase amount for Pre-ICO is different from ICO.
    */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal isWhitelisted(_beneficiary) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool atLeastMinimumAmount = _weiAmount >= MINIMUM_PURCHASE_AMOUNT_IN_WEI;

        if(now >= startTime && now < phaseOne) {
            atLeastMinimumAmount = _weiAmount >= PRE_ICO_MINIMUM_PURCHASE_AMOUNT_IN_WEI;
        }
        super._preValidatePurchase(_beneficiary, _weiAmount);
        require(msg.sender == _beneficiary);
        require(_weiAmount.add(weiRaised) <= fundingGoal);
        require(withinPeriod);
        require(atLeastMinimumAmount);
        require(crowdsaleActive);
    }

    /**
    * @dev Overrides _getTokenAmount function in Crowdsale.
    * Calculates token amount, inclusive of bonus, based on ETH contributed.
    * @param _weiAmount Value in wei to be converted into tokens
    * @return Number of tokens that can be purchased with the specified _weiAmount
    */
    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
        return _weiAmount.mul(getRate());
    }

    /**
    * @dev Calculates the token amount per ETH contributed based on the time now.
    * @return Rate of amount of GSTAR per Ether as of current time.
    */
    function getRate() public view returns (uint256) {
        //calculate bonus based on phases
        if(now >= startTime && now < phaseOne) {return 12000;}
        else if(now >= phaseOne && now < phaseTwo) {return 11500;}
        else if(now >= phaseTwo && now < phaseThree) {return 11200;}
        else if(now >= phaseThree && now < phaseFour) {return 10800;}
        else if(now >= phaseFour && now < phaseFive) {return 10400;}
        else if(now >= phaseFive && now < phaseSix) {return 10200;}
        else if(now >= phaseSix && now < endTime) {return 10000;}

        return rate;
    }

    /**
    * @dev Overrides _updatePurchasingState function from Crowdsale.
    * Updates tokenWeiRaised amount and funding goal status.
    */
    function _updatePurchasingState(address _beneficiary, uint256 _weiAmount) internal {
        tokensWeiRaised = tokensWeiRaised.add(_getTokenAmount(_weiAmount));
        updateFundingGoal();
    }

    /**
    * @dev Overrides _postValidatePurchase function from Crowdsale.
    * Updates beneficiary's contribution.
    */
    function _postValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
      depositedTokens[_beneficiary] = depositedTokens[_beneficiary].add(_getTokenAmount(_weiAmount));
    }

    /**
    * @dev Updates fundingGoal status.
    */
    function updateFundingGoal() internal {
        if(weiRaised >= fundingGoal){
            fundingGoalReached = true;
            GoalReached(weiRaised);
        }
    }

    /**
    * @dev Allows owner to start/unpause crowdsale.
    */
    function startCrowdsale() external onlyOwner {
        require(!crowdsaleActive);
        crowdsaleActive = true;
        StartCrowdsale();
    }

    /**
    * @dev Allows owner to stop/pause crowdsale.
    */
    function stopCrowdsale() external onlyOwner {
        require(crowdsaleActive);
        crowdsaleActive = false;
        StopCrowdsale();
    }

    /**
    * @dev Allows owner to enable release of tokens.
    */
    function enableTokenRelease() external onlyOwner {
        require(!canTokenRelease);
        canTokenRelease = true;
        TokenReleaseEnabled();
    }

    /**
    * @dev Allows owner to disable token release.
    */
    function disableTokenRelease() external onlyOwner {
        require(canTokenRelease);
        canTokenRelease = false;
        TokenReleaseDisabled();
    }

    /**
    * @dev Release tokens to multiple addresses.
    * @param contributors Addresses to release tokens to
    */
    function releaseTokens(address[] contributors) external onlyOwner {
        for (uint256 i = 0; i < contributors.length; i++) {

            // the amount of tokens to be distributed to contributor
            uint256 tokensAmount = depositedTokens[contributors[i]];

            //ensure that there is enough tokens to distribute
            require(token.balanceOf(address(this)) >= tokensAmount);
            super._deliverTokens(contributors[i], tokensAmount);

            depositedTokens[contributors[i]] = 0;
            tokensReleasedAmount = tokensReleasedAmount.add(tokensAmount);
        }
    }

    /**
    * @dev Stops crowdsale and release of tokens. Transfer remainining tokens back to owner.
    */
    function close() external onlyOwner {
        crowdsaleActive = false;
        canTokenRelease = false;
        token.transfer(owner, token.balanceOf(address(this)));
        Close();
    }

 }
