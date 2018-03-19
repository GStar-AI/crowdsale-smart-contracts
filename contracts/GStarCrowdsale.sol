pragma solidity ^0.4.19;

import "./math/SafeMath.sol";
import "./ownership/Ownable.sol";
import "./crowdsale/Crowdsale.sol";
import "./crowdsale/validation/WhitelistedCrowdsale.sol";

import "./GStarToken.sol";

/**
 * @title GStarCrowdsale
 * @dev This contract manages the crowdsale of GStar Tokens.
 * The crowdsale will involve three key timings - Start of Pre-fund, start time, end time,
 * The earlier the contribution, the larger the bonuses. (according to the bonus structure)
 * Tokens will be released to the contributors after the crowdsale.
 * There is only one owner at any one time. The owner can stop or start the crowdsale at anytime.
 */
contract GStarCrowdsale is WhitelistedCrowdsale {
    using SafeMath for uint256;

    // Start and end timestamps where contributions are allowed (both inclusive)
    // All timestamps are expressed in seconds instead of block number.
    uint256 public prefundStart;
    uint256 public startTime;
    uint256 public endTime;

    // Keeps track of contributors tokens
    mapping (address => uint256) public depositedTokens;

    // Minimum amount of ETH contribution during ICO and Pre-ICO period
    // Minimum of ETH contributed during ICO is 0.1ETH
    // Minimum of ETH contributed during pre-ICO is 1ETH
    uint256 public MINIMUM_PURCHASE_AMOUNT_IN_WEI = 10**17;
    uint256 public PRE_ICO_MINIMUM_PURCHASE_AMOUNT_IN_WEI = 1 ether;

    // Total tokens raised so far, bonus inclusive
    uint256 public tokensWeiRaised = 0;

    //Funding goal is 38,000 ETH, includes private contributions
    uint256 public fundingGoal = 38000 ether;
    bool public fundingGoalReached = false;

    //private contributions
    uint256 public privateContribution = 0;

    // Indicates if crowdsale is active
    bool public crowdsaleActive = false;

    // Indicates if tokens can be released
    bool public canTokenRelease = false;

    uint256 public tokensReleasedAmount = 0;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event GoalReached(uint256 totalEtherAmountRaised);
    event StartCrowdsale();
    event StopCrowdsale();
    event TokenReleaseEnabled();
    event TokenReleaseDisabled();
    event ReleaseTokens(address[] _beneficiaries);
    event Close();

    /**
    * @dev Constructor. Checks validity of the time entered.
    */
    function GStarCrowdsale(
        uint256 _prefundStart,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rate,
        address _wallet,
        GStarToken token
        ) public Crowdsale(_rate, _wallet, token) {

        require(_prefundStart != 0);
        require(_startTime != 0);
        require(_endTime != 0);
        //crowdsale is at least a month long, excluding pre-fund period
        require(_startTime.add(4 weeks) <= _endTime);
        require(_prefundStart < _startTime);

        prefundStart = _prefundStart;
        startTime = _startTime;
        endTime = _endTime;
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
        bool withinPeriod = now >= prefundStart && now <= endTime;
        bool atLeastMinimumAmount = _weiAmount >= MINIMUM_PURCHASE_AMOUNT_IN_WEI;

        if(now >= prefundStart && now < startTime) {
            atLeastMinimumAmount = _weiAmount >= PRE_ICO_MINIMUM_PURCHASE_AMOUNT_IN_WEI;
        }
        super._preValidatePurchase(_beneficiary, _weiAmount);
        require(msg.sender == _beneficiary);
        require(_weiAmount.add(weiRaised.add(privateContribution)) <= fundingGoal);
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
        //calculate bonus based on timing
        if(now <= startTime) {return 12000;} //pre-fund period
        if(now <= startTime.add(1 days)) {return 11500;}
        if(now <= startTime.add(3 days)) {return 11200;}
        if(now <= startTime.add(7 days)) {return 10800;}
        if(now <= startTime.add(2 weeks)) {return 10400;}
        if(now <= startTime.add(3 weeks)) {return 10200;}
        if(now <= startTime.add(4 weeks)) {return rate;}

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
    * @dev Change the private contribution, in ether, wei units.
    * Private contribution amount will be calculated into funding goal.
    */
    function changePrivateContribution(uint256 etherWeiAmount) external onlyOwner {
      privateContribution = etherWeiAmount;
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

        for (uint256 j = 0; j < contributors.length; j++) {

            // the amount of tokens to be distributed to contributor
            uint256 tokensAmount = depositedTokens[contributors[j]];

            //require the address to have sufficient tokens to deliver the tokens
            require(token.balanceOf(address(this)) >= tokensAmount);
            
            if(tokensAmount > 0) {
                super._deliverTokens(contributors[j], tokensAmount);

                depositedTokens[contributors[j]] = 0;

                //update state of release
                tokensReleasedAmount = tokensReleasedAmount.add(tokensAmount);
            }
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
