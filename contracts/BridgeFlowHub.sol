State Variables
    address public owner;
    address public validator;
    bool public paused;
    
    0.1% bridge fee
    uint256 public minBridgeAmount = 0.01 ether;
    uint256 public maxBridgeAmount = 100 ether;
    uint256 public dailyLimit = 1000 ether;
    uint256 public currentDailyVolume;
    uint256 public lastResetTimestamp;
    
    Chain IDs
    uint256 public immutable currentChainId;
    mapping(uint256 => bool) public supportedChains;
    
    Rate limiting
    mapping(address => mapping(uint256 => uint256)) public userDailyVolume;
    mapping(address => uint256) public lastUserReset;
    uint256 public userDailyLimit = 50 ether;
    
    Mappings
    mapping(uint256 => BridgeRequest) public bridgeRequests;
    mapping(address => TokenInfo) public tokenRegistry;
    mapping(address => uint256[]) public userBridgeHistory;
    
    Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyValidator() {
        require(msg.sender == validator || msg.sender == owner, "Only validator can call this function");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
    
    modifier whenPaused() {
        require(paused, "Contract is not paused");
        _;
    }
    
    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        require(_addr != address(this), "Cannot use contract address");
        _;
    }
    
    modifier validAmount(uint256 _amount) {
        require(_amount >= minBridgeAmount, "Amount below minimum");
        require(_amount <= maxBridgeAmount, "Amount exceeds maximum");
        _;
    }
    
    Constructor
    constructor(address _validator) {
        require(_validator != address(0), "Invalid validator address");
        owner = msg.sender;
        validator = _validator;
        
        Add current chain as supported
        supportedChains[currentChainId] = true;
        emit ChainAdded(currentChainId);
    }
    
    /**
     * @dev Add a supported blockchain network
     * @param chainId The chain ID to add
     */
    function addSupportedChain(uint256 chainId) external onlyOwner {
        require(!supportedChains[chainId], "Chain already supported");
        require(chainId > 0, "Invalid chain ID");
        
        supportedChains[chainId] = true;
        emit ChainAdded(chainId);
    }
    
    /**
     * @dev Remove a supported blockchain network
     * @param chainId The chain ID to remove
     */
    function removeSupportedChain(uint256 chainId) external onlyOwner {
        require(chainId != currentChainId, "Cannot remove current chain");
        require(supportedChains[chainId], "Chain not supported");
        
        supportedChains[chainId] = false;
        emit ChainRemoved(chainId);
    }
    
    /**
     * @dev Whitelist a token for bridging
     * @param token The token address
     * @param name Token name
     * @param symbol Token symbol
     * @param decimals Token decimals
     */
    function whitelistToken(
        address token,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) external onlyOwner validAddress(token) {
        require(!whitelistedTokens[token], "Token already whitelisted");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        
        whitelistedTokens[token] = true;
        tokenRegistry[token] = TokenInfo({
            name: name,
            symbol: symbol,
            decimals: decimals,
            isActive: true
        });
        
        emit TokenWhitelisted(token, name, symbol);
    }
    
    /**
     * @dev Remove a token from whitelist
     * @param token The token address
     */
    function removeToken(address token) external onlyOwner {
        require(whitelistedTokens[token], "Token not whitelisted");
        
        whitelistedTokens[token] = false;
        tokenRegistry[token].isActive = false;
        
        emit TokenRemoved(token);
    }
    
    /**
     * @dev Reset daily volume limit if 24 hours have passed
     */
    function resetDailyLimitIfNeeded() internal {
        if (block.timestamp >= lastResetTimestamp + 1 days) {
            currentDailyVolume = 0;
            lastResetTimestamp = block.timestamp;
        }
    }
    
    /**
     * @dev Reset user daily volume limit if 24 hours have passed
     * @param user The user address
     */
    function resetUserDailyLimitIfNeeded(address user) internal {
        if (block.timestamp >= lastUserReset[user] + 1 days) {
            userDailyVolume[user][block.timestamp / 1 days] = 0;
            lastUserReset[user] = block.timestamp;
        }
    }
    
    /**
     * @dev Initiate a bridge transfer for native tokens (ETH)
     * @param recipient The recipient address on the target chain
     * @param targetChainId The target chain ID
     */
    function bridgeNativeToken(
        address recipient,
        uint256 targetChainId
    ) external payable whenNotPaused nonReentrant validAddress(recipient) validAmount(msg.value) {
        require(supportedChains[targetChainId], "Target chain not supported");
        require(targetChainId != currentChainId, "Cannot bridge to same chain");
        
        uint256 amount = msg.value;
        uint256 fee = (amount * bridgeFee) / 1 ether;
        uint256 netAmount = amount - fee;
        
        Update volumes
        currentDailyVolume += netAmount;
        userDailyVolume[msg.sender][block.timestamp / 1 days] += netAmount;
        
        Native token
            amount: netAmount,
            targetChainId: targetChainId,
            timestamp: block.timestamp,
            nonce: nonce,
            completed: false
        });
        
        userBridgeHistory[msg.sender].push(nonce);
        
        emit BridgeInitiated(
            nonce,
            msg.sender,
            recipient,
            address(0),
            netAmount,
            targetChainId,
            block.timestamp
        );
        
        emit TokenLocked(address(0), msg.sender, netAmount, block.timestamp);
    }
    
    /**
     * @dev Complete a bridge transfer by releasing tokens
     * @param requestNonce The nonce of the original bridge request
     * @param recipient The recipient address
     * @param token The token address (address(0) for native)
     * @param amount The amount to release
     */
    function completeBridge(
        uint256 requestNonce,
        address recipient,
        address token,
        uint256 amount
    ) external onlyValidator whenNotPaused nonReentrant validAddress(recipient) {
        require(!processedNonces[requestNonce], "Nonce already processed");
        require(amount > 0, "Amount must be greater than zero");
        
        processedNonces[requestNonce] = true;
        
        if (token == address(0)) {
            For ERC20 tokens (would require additional implementation)
            revert("ERC20 tokens not yet implemented");
        }
        
        emit BridgeCompleted(requestNonce, recipient, token, amount, block.timestamp);
        emit TokenReleased(token, recipient, amount, block.timestamp);
    }
    
    /**
     * @dev Update the validator address
     * @param newValidator The new validator address
     */
    function updateValidator(address newValidator) external onlyOwner validAddress(newValidator) {
        address oldValidator = validator;
        validator = newValidator;
        emit ValidatorUpdated(oldValidator, newValidator);
    }
    
    /**
     * @dev Update bridge fee
     * @param newFee The new fee in wei (e.g., 0.001 ether for 0.1%)
     */
    function updateBridgeFee(uint256 newFee) external onlyOwner {
        require(newFee <= 0.01 ether, "Fee cannot exceed 1%");
        uint256 oldFee = bridgeFee;
        bridgeFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }
    
    /**
     * @dev Update bridge limits
     * @param _minAmount Minimum bridge amount
     * @param _maxAmount Maximum bridge amount
     * @param _dailyLimit Daily bridge limit
     */
    function updateLimits(
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _dailyLimit
    ) external onlyOwner {
        require(_minAmount > 0, "Min amount must be greater than zero");
        require(_maxAmount > _minAmount, "Max must be greater than min");
        require(_dailyLimit >= _maxAmount, "Daily limit must be >= max amount");
        
        minBridgeAmount = _minAmount;
        maxBridgeAmount = _maxAmount;
        dailyLimit = _dailyLimit;
        
        emit LimitsUpdated(_minAmount, _maxAmount, _dailyLimit);
    }
    
    /**
     * @dev Update user daily limit
     * @param _userDailyLimit New user daily limit
     */
    function updateUserDailyLimit(uint256 _userDailyLimit) external onlyOwner {
        require(_userDailyLimit > 0, "Limit must be greater than zero");
        userDailyLimit = _userDailyLimit;
    }
    
    /**
     * @dev Get bridge request details
     * @param requestNonce The nonce of the bridge request
     */
    function getBridgeRequest(uint256 requestNonce) external view returns (
        address sender,
        address recipient,
        address token,
        uint256 amount,
        uint256 targetChainId,
        uint256 timestamp,
        bool completed
    ) {
        BridgeRequest memory request = bridgeRequests[requestNonce];
        return (
            request.sender,
            request.recipient,
            request.token,
            request.amount,
            request.targetChainId,
            request.timestamp,
            request.completed
        );
    }
    
    /**
     * @dev Get user's bridge history
     * @param user The user address
     */
    function getUserBridgeHistory(address user) external view returns (uint256[] memory) {
        return userBridgeHistory[user];
    }
    
    /**
     * @dev Get token information
     * @param token The token address
     */
    function getTokenInfo(address token) external view returns (
        string memory name,
        string memory symbol,
        uint8 decimals,
        bool isActive
    ) {
        TokenInfo memory info = tokenRegistry[token];
        return (info.name, info.symbol, info.decimals, info.isActive);
    }
    
    /**
     * @dev Check if a chain is supported
     * @param chainId The chain ID to check
     */
    function isChainSupported(uint256 chainId) external view returns (bool) {
        return supportedChains[chainId];
    }
    
    /**
     * @dev Get current daily remaining limit
     */
    function getRemainingDailyLimit() external view returns (uint256) {
        if (block.timestamp >= lastResetTimestamp + 1 days) {
            return dailyLimit;
        }
        return dailyLimit > currentDailyVolume ? dailyLimit - currentDailyVolume : 0;
    }
    
    /**
     * @dev Get user's remaining daily limit
     * @param user The user address
     */
    function getUserRemainingDailyLimit(address user) external view returns (uint256) {
        if (block.timestamp >= lastUserReset[user] + 1 days) {
            return userDailyLimit;
        }
        uint256 used = userDailyVolume[user][block.timestamp / 1 days];
        return userDailyLimit > used ? userDailyLimit - used : 0;
    }
    
    /**
     * @dev Pause the contract in case of emergency
     */
    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit ContractPaused(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit ContractUnpaused(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Emergency withdrawal function for owner
     * @param token Token address (address(0) for native)
     * @param amount Amount to withdraw
     * @param to Recipient address
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyOwner whenPaused validAddress(to) {
        require(amount > 0, "Amount must be greater than zero");
        
        if (token == address(0)) {
            require(address(this).balance >= amount, "Insufficient balance");
            payable(to).transfer(amount);
        } else {
            Receive function to accept native tokens
    receive() external payable {
        Fallback function
    fallback() external payable {
        revert("Invalid function call");
    }
}
// 
Contract End
// 
