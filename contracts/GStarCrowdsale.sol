pragma solidity ^0.4.18;

import "./math/SafeMath.sol";
import "./ownership/Ownable.sol";
import "./crowdsale/Crowdsale.sol";
import "./crowdsale/validation/WhitelistedCrowdsale.sol";

import "./GStarToken.sol";

/**
 * @title GStarCrowdsale
 * @dev This contract manages the crowdsale of GStar Tokens.
 * The crowdsale will involve two key timings - Start and ending of funding.
 * The earlier the contribution, the larger the bonuses. (according to the bonus structure)
 * Tokens will be released to the contributors after the crowdsale.
 * There is only one owner at any one time. The owner can stop or start the crowdsale at anytime.
 */
contract GStarCrowdsale is WhitelistedCrowdsale {
    using SafeMath for uint256;

    // Start and end timestamps where contributions are allowed (both inclusive)
    // All timestamps are expressed in seconds instead of block number.
    uint256 constant public presaleStartTime = 1531051200; // 8 Jul 2018 1200h
    uint256 constant public startTime = 1532260800; // 22 Jul 2018 1200h
    uint256 constant public endTime = 1534593600; // 18 Aug 2018 1200h

    // Keeps track of contributors tokens
    mapping (address => uint256) public depositedTokens;

    // Minimum amount of ETH contribution during ICO period
    // Minimum of ETH contributed during ICO is 0.1ETH
    uint256 constant public MINIMUM_PRESALE_PURCHASE_AMOUNT_IN_WEI = 1 ether;
    uint256 constant public MINIMUM_PURCHASE_AMOUNT_IN_WEI = 0.1 ether;

    // Total tokens raised so far, bonus inclusive
    uint256 public tokensWeiRaised = 0;

    //Funding goal is 76,000 ETH, includes private contributions
    uint256 constant public fundingGoal = 76000 ether;
    uint256 constant public presaleFundingGoal = 1000 ether;
    bool public fundingGoalReached = false;
    bool public presaleFundingGoalReached = false;

    //private contributions
    uint256 public privateContribution = 0;

    // Indicates if crowdsale is active
    bool public crowdsaleActive = false;
    bool public isCrowdsaleClosed = false;

    uint256 public tokensReleasedAmount = 0;


    /*==================================================================== */
    /*============================== EVENTS ============================== */
    /*==================================================================== */

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event GoalReached(uint256 totalEtherAmountRaised);
    event PresaleGoalReached(uint256 totalEtherAmountRaised);
    event StartCrowdsale();
    event StopCrowdsale();
    event ReleaseTokens(address[] _beneficiaries);
    event Close();

    /**
    * @dev Constructor. Checks validity of the time entered.
    */
    function GStarCrowdsale (
        uint256 _rate,
        address _wallet,
        GStarToken token
        ) public Crowdsale(_rate, _wallet, token) {
    }


    /*==================================================================== */
    /*========================= PUBLIC FUNCTIONS ========================= */
    /*==================================================================== */

    /**
    * @dev Override buyTokens function as tokens should only be delivered when released.
    * @param _beneficiary Address receiving the tokens.
    */
    function buyTokens(address _beneficiary) public payable {

        uint256 weiAmount = msg.value;
        _preValidatePurchase(_beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        // update state
        weiRaised = weiRaised.add(weiAmount);
        
        emit TokenPurchase(msg.sender, _beneficiary, weiAmount, tokens);

        _updatePurchasingState(_beneficiary, weiAmount);

        _forwardFunds();
        _processPurchase(_beneficiary, weiAmount);
    }

    /**
    * @dev Calculates the token amount per ETH contributed based on the time now.
    * @return Rate of amount of GSTAR per Ether as of current time.
    */
    function getRate() public view returns (uint256) {
        //calculate bonus based on timing
        if (block.timestamp <= startTime) { return ((rate / 100) * 120); } // 20 percent bonus on presale period, returns 12000
        if (block.timestamp <= startTime.add(1 days)) {return ((rate / 100) * 108);} // 8 percent bonus on day one, return 10800

        return rate;
    }


    /*==================================================================== */
    /*======================== EXTERNAL FUNCTIONS ======================== */
    /*==================================================================== */

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
        require(!isCrowdsaleClosed);

        crowdsaleActive = true;
        emit StartCrowdsale();
    }

    /**
    * @dev Allows owner to stop/pause crowdsale.
    */
    function stopCrowdsale() external onlyOwner {
        require(crowdsaleActive);
        crowdsaleActive = false;
        emit StopCrowdsale();
    }

    /**
    * @dev Release tokens to multiple addresses.
    * @param contributors Addresses to release tokens to
    */
    function releaseTokens(address[] contributors) external onlyOwner {

        for (uint256 j = 0; j < contributors.length; j++) {

            // the amount of tokens to be distributed to contributor
            uint256 tokensAmount = depositedTokens[contributors[j]];

            if (tokensAmount > 0) {
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
        isCrowdsaleClosed = true;
        
        token.transfer(owner, token.balanceOf(address(this)));
        emit Close();
    }


    /*==================================================================== */
    /*======================== INTERNAL FUNCTIONS ======================== */
    /*==================================================================== */

    /**
    * @dev Overrides _preValidatePurchase function in Crowdsale.
    * Requires purchase is made within crowdsale period.
    * Requires contributor to be the beneficiary.
    * Requires purchase value and address to be non-zero.
    * Requires amount not to exceed funding goal.
    * Requires purchase value to be higher or equal to minimum amount.
    * Requires contributor to be whitelisted.
    */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
        bool withinPeriod = now >= presaleStartTime && now <= endTime;

        bool atLeastMinimumAmount = false;

        if(block.timestamp <= startTime) {
            // during presale period

            require(_weiAmount.add(weiRaised.add(privateContribution)) <= presaleFundingGoal);
            atLeastMinimumAmount = _weiAmount >= MINIMUM_PRESALE_PURCHASE_AMOUNT_IN_WEI;
            
        } else {
            // during funding period
            atLeastMinimumAmount = _weiAmount >= MINIMUM_PURCHASE_AMOUNT_IN_WEI;
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
    * @dev Overrides _updatePurchasingState function from Crowdsale.
    * Updates tokenWeiRaised amount and funding goal status.
    */
    function _updatePurchasingState(address _beneficiary, uint256 _weiAmount) internal {
        tokensWeiRaised = tokensWeiRaised.add(_getTokenAmount(_weiAmount));
        _updateFundingGoal();
    }

    /**
    * @dev Overrides _processPurchase function from Crowdsale.
    * Adds the tokens purchased to the beneficiary.
    * @param _tokenAmount The token amount in wei before multiplied by the rate.
    */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
        depositedTokens[_beneficiary] = depositedTokens[_beneficiary].add(_getTokenAmount(_tokenAmount));
    }

    /**
    * @dev Updates fundingGoal status.
    */
    function _updateFundingGoal() internal {
        if (weiRaised.add(privateContribution) >= fundingGoal) {
            fundingGoalReached = true;
            emit GoalReached(weiRaised.add(privateContribution));
        }

        if(block.timestamp <= startTime) {
            if(weiRaised.add(privateContribution) >= presaleFundingGoal) {
                
                presaleFundingGoalReached = true;
                emit PresaleGoalReached(weiRaised.add(privateContribution));
            }
        }
    }



}
