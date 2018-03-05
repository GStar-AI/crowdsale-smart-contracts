pragma solidity ^0.4.18;

import "./math/SafeMath.sol";
import "./ownership/Ownable.sol";
import "./RefundVault.sol";
//import "./GStarToken.sol";

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
contract GStarCrowdsale is Ownable {
    using SafeMath for uint256;

    // The address of the GStar Token contract deployed.
    GStarToken public gStarToken;
    RefundVault public refundVault;

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

    // The base rate the buyer gets for each ETH invested.
    // This rate is exclusive of any bonuses.
    uint256 public GSTAR_PER_ETH = 10000;

    // Parameters for this crowdsale.
    uint256 public MINIMUM_PURCHASE_AMOUNT_IN_WEI = 10**17; // the minimum of ETH that buyer can purchase is 0.1ETH
    uint256 public PRE_ICO_MINIMUM_PURCHASE_AMOUNT_IN_WEI = 10**18; // the minimum of ETH that buyer can purchase during pre-ICO is 1ETH
    uint256 public fundingGoal = 10 ether; //expressed in amount of Ether in Wei units
    uint256 public tokensRaisedInWei = 0;
    uint256 public etherRaisedInWei = 0;
    bool fundingGoalReached = false;
    bool crowdsaleActive = false;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event GoalReached(uint256 totalEtherAmountRaised);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event StartCrowdsale();
    event StopCrowdsale();
    event SettlementEnabled();
    event SettlementEnded();
    event RefundClaimed(address investor, uint256 etherWeiAmount, bool success);
    event TokensClaimed(address investor, uint256 tokensWeiAmount);
    event Whitelisted(address beneficiary);
    event Delisted(address beneficiary);
    event AddedMultipleToWhitelist(address[] beneficiaries);
    event BulkWhitelistAndReleaseTokens(address[] beneficiaries);


    /**
    * @dev Constructor function. Checks validity of the time entered, sets owner,
    * and creates new RefundVault.
    * @param deployedGStar The address of the GStarToken this contract crowdsells.
    */
    function GStarCrowdsale(address deployedGStar, address deployedRefundVault) public {
        require(startTime < phaseOne);
        require(phaseOne < phaseTwo);
        require(phaseTwo < phaseThree);
        require(phaseThree < phaseFour);
        require(phaseFour < phaseFive);
        require(phaseFive < phaseSix);
        require(phaseSix < endTime);
        require(deployedGStar != address(0));
        require(deployedRefundVault != address(0));

        require(fundingGoal > 0);

        owner = msg.sender;
        gStarToken = GStarToken(deployedGStar);
        refundVault = RefundVault(deployedRefundVault);
    }

    /**
    * @dev Fallback function can be used to buy tokens when crowdsale is active.
    */
    function () public payable {
        require(crowdsaleActive);
        buyTokens(msg.sender);
    }

    /**
    * @dev Actual buy tokens function. Buyers are restricted to only buy tokens for themselves.
    * @param beneficiary The address that receives the tokens purchased.
    */
    function buyTokens(address beneficiary) public payable {
        require(beneficiary != address(0));
        require(msg.sender == beneficiary);
        require(validPurchase());

        // throws if this purchase exceed funding goal
        uint256 weiAmount = msg.value;
        require(weiAmount.add(etherRaisedInWei) <= fundingGoal);

        // calculate total token amount purchased, bonus included
        uint256 tokens = getRate().mul(weiAmount);

        // update state
        etherRaisedInWei = etherRaisedInWei.add(weiAmount);
        tokensRaisedInWei = tokensRaisedInWei.add(tokens);

        // forward ETH amount to RefundVault
        refundVault.deposit.value(msg.value)(msg.sender, tokens);

        TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

        // checks and update fundingGoal
        updateFundingGoal();
    }

    /**
    * @dev Calculates the token amount per ether based on the time now.
    * Returns rate of amount of GSTAR per Ether as of current time.
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

        return GSTAR_PER_ETH;
    }

    /**
    * @dev Checks and updates fundingGoal status.
    * Returns true if funding goal is reached.
    */
    function updateFundingGoal() internal returns (bool) {
        if(etherRaisedInWei >= fundingGoal){
            fundingGoalReached = true;
            GoalReached(etherRaisedInWei);
            return true;
        } else {
            return false;
        }
    }

    /**
    * @dev Checks whether the cap has been reached.
    * Returns true if funding goal is reached.
    */
    function isFundingGoalReached() public view returns (bool) {
        return etherRaisedInWei >= fundingGoal;
    }

    /**
    * @dev Displays if crowdsale is active.
    * Returns true if crowdsale is active.
    */
    function isCrowdsaleActive() public view returns (bool) {
        return crowdsaleActive;
    }


    /**
    * @dev Checks if purchase is made within crowdsale period.
    * Checks if purchase is non-zero.
    * Checks if purchase is higher or equal to minimum amount.
    * The minimum purchase amount for Pre-ICO is different from ICO.
    * @return Returns true if purchase meets all requirements.
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
        require(!crowdsaleActive);
        crowdsaleActive = true;
        StartCrowdsale();
    }

    /**
    * @dev Allows owner to stop/pause crowdsale.
    */
    function stopCrowdsale() public onlyOwner {
        require(crowdsaleActive);
        crowdsaleActive = false;
        StopCrowdsale();
    }

    /**
    * @dev Allows buyers to claim their tokens after the purchase.
    * Buyers have to claim their tokens with the wallet address they used to send ether.
    */
    function claimTokens() public {

        uint256 tokensAmount = refundVault.tokensDeposited(msg.sender);
        refundVault.claimTokens(msg.sender);
        TokensClaimed(msg.sender, tokensAmount);
    }

    /**
    * @dev Allows buyers to claim refund after the purchase.
    * Buyers have to claim refund with the wallet address they used to send ether.
    */
    function claimRefund() public {

        uint256 tokenAmount = refundVault.tokensDeposited(msg.sender);
        uint256 refundAmount = refundVault.etherDeposited(msg.sender);
        bool refundStatus = refundVault.refund(msg.sender);

        if(refundStatus) {
            tokensRaisedInWei = tokensRaisedInWei.sub(tokenAmount);
            etherRaisedInWei = etherRaisedInWei.sub(refundAmount);
        }
        RefundClaimed(msg.sender, refundAmount, refundStatus);
    }


    /**
    * @dev Allows owner to enable refund and release of tokens.
    * Once settlement is enabled, no further purchase of tokens is possible.
    */
    function enableSettlement() public onlyOwner {
        refundVault.enableSettlement();
        crowdsaleActive = false;
        SettlementEnabled();
    }

    /**
    * @dev Allows owner to end settlement.
    * Upon ending, ether in the refund vault will be sent to the wallet.
    * Settlement can only be ended once and is not revertible.
    */
    function endSettlement() public onlyOwner {
        refundVault.endSettlement();
        SettlementEnded();
    }

    /**
    * @dev Allows owner to add buyers to whitelist upon confirmation.
    * @param beneficiary Address to whitelist.
    */
    function addToWhitelist(address beneficiary) public onlyOwner {
        refundVault.addToWhiteList(beneficiary);
        Whitelisted(beneficiary);
    }

    /**
    * @dev Allows owner to remove buyers from whitelist.
    * @param beneficiary Address to remove from whitelist.
    */
    function removeFromWhitelist(address beneficiary) public onlyOwner {
        refundVault.removeFromWhitelist(beneficiary);
        Delisted(beneficiary);
    }

    /**
    * @dev Allows owner to add multiple addresses to whitelist.
    * @param beneficiaries Array of addresses to add to whitelist.
    */
    function addManyToWhitelist(address[] beneficiaries) public onlyOwner {
        refundVault.addManyToWhitelist(beneficiaries);
        AddedMultipleToWhitelist(beneficiaries);
    }

    /**
    * @dev Allows owner to add multiple addresses to whitelist and release tokens.
    * @param beneficiaries Array of addresses to be added to whitelist and release tokens to.
    */
    function whitelistAndReleaseTokens(address[] beneficiaries) public onlyOwner {
        refundVault.whitelistAndReleaseTokens(beneficiaries);
        BulkWhitelistAndReleaseTokens(beneficiaries);
    }
 }
