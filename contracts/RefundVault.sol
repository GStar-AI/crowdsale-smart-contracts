pragma solidity ^0.4.18;

import "./math/SafeMath.sol";
import "./ownership/Ownable.sol";


interface GStarToken {
    function transfer(address to, uint256 value) public returns (bool);
    function balanceOf(address who) public view returns (uint256);
}


/**
 * @title RefundVault
 * @dev This contract is used for storing funds while a crowdsale is in progress.
 * The RefundVault must hold tokens for tokens to be released.
 * Buyers can claim for a full refund for his ether against the tokens.
 * Once tokens is claimed, no refund can be made.
 */
contract RefundVault is Ownable {
    using SafeMath for uint256;

    enum State { Active, Settling, Closed }

    GStarToken public gStarToken;

    mapping (address => bool) public whitelist;
    mapping (address => uint256) public depositedEther;
    mapping (address => uint256) public depositedTokens;
    address public wallet = 0x9A1C6fA66DbaEA367e21403609628a40Cf345b6e;
    State public state;

	event SettlementEnabled();
    event SettlementEnded();
    event Refunded(address indexed beneficiary, uint256 weiAmount);
    event TokensClaimed(address investor, uint256 tokensWeiAmount);
    event Whitelisted(address beneficiary);
    event Delisted(address beneficiary);
    event AddedMultipleToWhitelist(address[] beneficiaries);
    event BulkWhitelistAndReleaseTokens(address[] beneficiaries);
    event Deposited(address investor, uint256 etherWeiAmount, uint256 tokensWeiAmount);

    /**
    * @dev Constructor function.
    * @param deployedGStar The address of the deployed GSTAR contract.
    */
    function RefundVault(address deployedGStar) public {
        require(deployedGStar != address(0));
        owner = msg.sender;
        state = State.Active;
        gStarToken = GStarToken(deployedGStar);
    }

    /**
    * @dev This function updates the ether deposited to the investor and the token amount bought.
    * @param investor Investor address
    * @param tokensWeiAmount Amount of tokens bought.
    */
    function deposit(address investor, uint256 tokensWeiAmount) onlyOwner external payable {
        require(state == State.Active);
        depositedTokens[investor] = depositedTokens[investor].add(tokensWeiAmount);
        depositedEther[investor] = depositedEther[investor].add(msg.value);

        Deposited(investor, msg.value, tokensWeiAmount);
    }

	/**
	* @dev End settlement period. This function can only be called once and it is not reversisble.
	* Funds forwarded to wallet after closing.
	*/
	function endSettlement() onlyOwner external {
		require(state == State.Settling);
		state = State.Closed;

		wallet.transfer(this.balance);

		uint256 currentRemainingBalance = gStarToken.balanceOf(address(this));
		gStarToken.transfer(wallet, currentRemainingBalance);
		SettlementEnded();
	}

	/**
	* @dev Stops crowdsale and enable release of tokens and refund of ethers.
	*/
	function enableSettlement() onlyOwner external {
		require(state == State.Active);
		state = State.Settling;
		SettlementEnabled();
	}

	/**
	* @dev This function refunds the investor the full ether amount.
	* @param investor Investor address
	// Returns true if refund is successful.
	*/
	function refund(address investor) onlyOwner external returns (bool) {
		require(state == State.Settling);
		require(depositedTokens[investor] > 0);
		require(depositedEther[investor] > 0);

		uint256 depositedEtherValue = depositedEther[investor];
		depositedEther[investor] = 0;
		depositedTokens[investor] = 0;

		investor.transfer(depositedEtherValue);

		Refunded(investor, depositedEtherValue);
		return true;
	}

	/**
	* @dev This function releases the full amount of tokens to the investor.
	* @param investor Investor address
	*/
	function claimTokens(address investor) onlyOwner external {
		require(state == State.Settling);
		require(depositedTokens[investor] > 0);
		require(depositedEther[investor] > 0);
		require(whitelist[investor]);
		require(gStarToken.balanceOf(address(this)) > depositedTokens[investor]);

		uint256 tokensAmount = depositedTokens[investor];

		depositedTokens[investor] = 0;
		depositedEther[investor] = 0;

		gStarToken.transfer(investor, tokensAmount);
		TokensClaimed(investor, tokensAmount);
	}

	/**
	* @dev Add buyer to whitelist.
	* @param beneficiary Address to add to whitelist.
	*/
	function addToWhiteList(address beneficiary) external onlyOwner {
		require(!whitelist[beneficiary]);
		whitelist[beneficiary] = true;
		Whitelisted(beneficiary);
	}

	/**
	* @dev Add multiple addresses to the whitelist.
	* @param beneficiaries Array of addresses to add to whitelist.
	*/
	function addManyToWhitelist(address[] beneficiaries) external onlyOwner {
		for (uint256 i = 0; i < beneficiaries.length; i++) {
			whitelist[beneficiaries[i]] = true;
		}
		AddedMultipleToWhitelist(beneficiaries);
	}

	/**
	* @dev Add multiple addresses to the whitelist and release tokens to them.
	* @param beneficiaries Array of addresses to add to whitelist and release tokens to.
	*/
	function whitelistAndReleaseTokens(address[] beneficiaries) external onlyOwner {
		require(state == State.Settling);
		for (uint256 i = 0; i < beneficiaries.length; i++) {
			address currentBeneficiary = beneficiaries[i];
			whitelist[currentBeneficiary] = true;

			if(depositedTokens[currentBeneficiary] > 0 && depositedEther[currentBeneficiary] > 0) {
				uint256 tokensAmount = depositedTokens[currentBeneficiary];

				if(tokensAmount > 0 && gStarToken.balanceOf(address(this)) > tokensAmount) {
					depositedTokens[currentBeneficiary] = 0;
					depositedEther[currentBeneficiary] = 0;
					gStarToken.transfer(currentBeneficiary, tokensAmount);
				}
			}
		}
		BulkWhitelistAndReleaseTokens(beneficiaries);
	}

	/**
	* @dev Remove single address from whitelist.
	* @param beneficiary Address to remove from whitelist.
	*/
	function removeFromWhitelist(address beneficiary) external onlyOwner {
		require(whitelist[beneficiary]);
		whitelist[beneficiary] = false;
		Delisted(beneficiary);
	}

	/**
	* @dev Shows amount of tokens deposited in refund vault.
	* @param beneficiary Address of beneficiary
	* Returns Wei amount of tokens deposited in refund vault
	*/
	function tokensDeposited(address beneficiary) public view returns (uint256) {
		return depositedTokens[beneficiary];
	}

	/**
	* @dev Shows amount of ether deposited in refund vault.
	* @param beneficiary Address of beneficiary
	* Returns Wei amount of ether deposited in refund vault
	*/
	function etherDeposited(address beneficiary) public view returns (uint256) {
		return depositedEther[beneficiary];
	}

	/**
	* @dev Shows if beneficiary is whitelisted.
	* @param beneficiary Address of beneficiary
	* Returns true if whitelisted.
	*/
	function isWhitelisted(address beneficiary) public view returns (bool) {
		return whitelist[beneficiary];
	}
}
