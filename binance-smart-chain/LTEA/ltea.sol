// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract LiberTeaCoin is ERC20, Ownable, Pausable {
    // Tokenomics
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10**18; // 1 Billion Tokens
    uint256 public constant MAX_SUPPLY = 2_000_000_000 * 10**18; // 2 Billion Tokens (Hard Cap)
    uint256 public constant STAKING_REWARDS_CAP = 500_000_000 * 10**18; // 500 Million Tokens for Staking Rewards
    uint256 public totalMinted; // Tracks total minted tokens
    uint256 public totalStakingRewardsMinted; // Tracks staking rewards minted

    // Staking Variables
    struct StakingInfo {
        uint256 stakedAmount;
        uint256 lastUpdateBlock;
    }
    mapping(address => StakingInfo) public stakers;
    uint256 public totalStaked;
    uint256 public blockReward;
    uint256 public minStakingAmount;
    uint256 public globalRewardMultiplier = 1;
    bool public stakingEnabled;
    uint256 public stakingStartBlock;

    // Staking Timelocks and Penalties
    mapping(address => uint256) public stakingStartTime;
    uint256 public constant MIN_STAKING_PERIOD = 7 days;
    uint256 public constant MIN_CLAIM_INTERVAL = 1 days;
    mapping(address => uint256) public lastClaimTime;

    address constant DEAD_WALLET = 0x000000000000000000000000000000000000dEaD;


    // Tokenomics Allotments
    struct Allotment {
        uint256 amount;
        string label;
    }
    mapping(address => Allotment) public allotments;
    mapping(address => uint256) public allotmentCount;
    uint256 public constant MAX_ALLOTMENTS_PER_USER = 10; // Max allotments per user

    // Events
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event StakingEnabled(uint256 blockReward, uint256 minStakingAmount);
    event StakingDisabled();
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event AllotmentCreated(address indexed beneficiary, uint256 amount, string label);
    event AllotmentWithdrawn(address indexed beneficiary, uint256 amount);
    event BeneficiaryUpdated(address indexed oldBeneficiary, address indexed newBeneficiary);

    // Constructor
    constructor() ERC20("LiberTea Coin", "LTEA") Ownable(msg.sender) {
    _mint(msg.sender, INITIAL_SUPPLY);
    totalMinted = INITIAL_SUPPLY;
    }


    // Modifiers
    modifier whenStakingEnabled() {
        require(stakingEnabled, "Staking is disabled");
        _;
    }

    modifier whenStakingDisabled() {
        require(!stakingEnabled, "Staking is enabled");
        _;
    }

    // Minting Functionality
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalMinted + amount <= MAX_SUPPLY, "Cannot exceed max supply");
        totalMinted += amount;
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    // Burning Functionality
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    // Staking Functionality
    function enableStaking(uint256 _blockReward, uint256 _minStakingAmount) external onlyOwner whenStakingDisabled {
        require(_blockReward > 0, "Block reward must be greater than 0");
        require(_minStakingAmount > 0, "Minimum staking amount must be greater than 0");

        stakingEnabled = true;
        blockReward = _blockReward;
        minStakingAmount = _minStakingAmount;
        stakingStartBlock = block.number;

        emit StakingEnabled(_blockReward, _minStakingAmount);
    }

    function disableStaking() external onlyOwner whenStakingEnabled {
        stakingEnabled = false;
        emit StakingDisabled();
    }

    function stake(uint256 amount) external whenNotPaused whenStakingEnabled {
        require(amount >= minStakingAmount, "Amount below minimum staking amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        _updateReward(msg.sender);
        _transfer(msg.sender, address(this), amount);
        stakers[msg.sender].stakedAmount += amount;
        totalStaked += amount;
        stakingStartTime[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external whenNotPaused whenStakingEnabled {
        require(stakers[msg.sender].stakedAmount >= amount, "Insufficient staked amount");

        uint256 penalty = 0;

        if (block.timestamp < stakingStartTime[msg.sender] + MIN_STAKING_PERIOD) {
            penalty = (amount * 10) / 100;
        }
        _updateReward(msg.sender);
        unchecked {
            stakers[msg.sender].stakedAmount -= amount;
            totalStaked -= amount;
        }

        if (penalty > 0) {
            if (balanceOf(address(this)) >= penalty) { // Ensure contract has enough balance
                _transfer(address(this), DEAD_WALLET, penalty); // Transfer to burn address
                amount -= penalty;
            } else {
                penalty = 0;
            }
        }
        
        _transfer(address(this), msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function claimReward() external whenNotPaused whenStakingEnabled {
        require(block.timestamp >= lastClaimTime[msg.sender] + MIN_CLAIM_INTERVAL, "Cooldown period not over");
        require(block.timestamp >= stakingStartTime[msg.sender] + MIN_STAKING_PERIOD, "Must stake for 7 days before claiming rewards");

        uint256 reward = _calculateReward(msg.sender);
        require(reward > 0, "No reward to claim");
        require(totalStakingRewardsMinted + reward <= STAKING_REWARDS_CAP, "Staking rewards cap reached");

        _mint(msg.sender, reward);
        totalStakingRewardsMinted += reward;
        lastClaimTime[msg.sender] = block.timestamp;
        stakers[msg.sender].lastUpdateBlock = block.number;

        emit RewardClaimed(msg.sender, reward);
    }



    function _updateReward(address user) internal {
        if (block.timestamp >= stakingStartTime[user] + MIN_STAKING_PERIOD) {

        uint256 reward = _calculateReward(user);

        unchecked {
            if (reward > 0 && totalMinted + reward <= MAX_SUPPLY && totalStakingRewardsMinted + reward <= STAKING_REWARDS_CAP) {
                _mint(user, reward);
                totalStakingRewardsMinted += reward;
                totalMinted += reward;
            }
        }
        }

        stakers[user].lastUpdateBlock = block.number;
        
    }



    function _calculateReward(address user) internal view returns (uint256) {
        if (stakers[user].stakedAmount == 0 || totalStaked == 0) return 0;

        unchecked {
            uint256 blocksSinceLastUpdate = block.number - stakers[user].lastUpdateBlock;
            uint256 rewardPerBlock = (blockReward * stakers[user].stakedAmount) / totalStaked;
            return blocksSinceLastUpdate * rewardPerBlock * globalRewardMultiplier;
        }
    }


    // Tokenomics Allotments
    function createAllotment(address beneficiary, uint256 amount, string memory label) external onlyOwner {
        require(allotments[beneficiary].amount == 0, "Allotment already exists. Withdraw first.");        
        require(allotmentCount[beneficiary] < MAX_ALLOTMENTS_PER_USER, "Max allotments reached");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        allotments[beneficiary] = Allotment(amount, label);
        _transfer(msg.sender, address(this), amount);
        allotmentCount[beneficiary]++;

        emit AllotmentCreated(beneficiary, amount, label);
    }

    function updateBeneficiary(address oldBeneficiary, address newBeneficiary) external onlyOwner {
    require(allotments[oldBeneficiary].amount > 0, "No allotment for old beneficiary");

    allotments[newBeneficiary] = allotments[oldBeneficiary];
    delete allotments[oldBeneficiary];

    emit BeneficiaryUpdated(oldBeneficiary, newBeneficiary);
    }

    function withdrawAllotment() external {
        require(allotments[msg.sender].amount > 0, "No allotment to withdraw");

        uint256 amount = allotments[msg.sender].amount;
        allotments[msg.sender].amount = 0;
        _transfer(address(this), msg.sender, amount);

        emit AllotmentWithdrawn(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(address from, address to, uint256 amount) internal override whenNotPaused {
    super._update(from, to, amount);
}

    

}
