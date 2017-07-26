pragma solidity ^0.4.9;


/// @title Abstract token contract - Functions to be implemented by token contracts.
contract Token {
    function transfer(address to, uint256 value) returns (bool success);
    function transferFrom(address from, address to, uint256 value) returns (bool success);
    function approve(address spender, uint256 value) returns (bool success);

    // This is not an abstract function, because solc won't recognize generated getter functions for public variables as functions.
    function totalSupply() constant returns (uint256 supply) {}
    function balanceOf(address owner) constant returns (uint256 balance);
    function allowance(address owner, address spender) constant returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract DelphyICO {
    /*
     *  Events
     */
    event BidSubmission(address indexed sender, uint256 amount);
    
    /*
     *  Constants
     */
    uint constant public STEP1_PERIOD = 2 days;
    uint constant public STEP2_PERIOD = 4 days;
    uint constant public STEP3_PERIOD = 7 days;
    uint constant public TOTAL_PERIOD = 13 days;
    
    uint constant public MAX_TOKENS_SOLD = 18000000 * 10**18; // 18M
    
    /*
     *  Enums
     */
    enum Stages {
        IcoDeployed,
        IcoSetUp,
        IcoStarted,
        IcoEnded,
        TradingStarted
    }
     
    /*
     *  Storage
     */
    Token public delphyToken;
    address public wallet;
    address public owner;
    uint public startBlock;
    uint public startTime;
    uint public endTime;
    uint public totalReceived;
    uint public soldTokens;
    mapping (address => uint)[3] public bids;
    mapping (address => uint) public bidToken;
    Stages public stage;
     
    /*
     *  Modifiers
     */
    modifier atStage(Stages _stage) {
        require (stage == _stage);
            // Contract not in expected state
            
        _;
    }
     
    modifier isValidPayload() {
        require (msg.data.length == 4 || msg.data.length == 36);
        
        _;
    }

    modifier isOwner() {
        require (msg.sender == owner);
            // Only owner is allowed to proceed
        _;
    }

    modifier isWallet() {
        require (msg.sender == wallet);
            // Only wallet is allowed to proceed
            
        _;
    }
     
    /*
     *  Public functions
     */
     
    function sub(uint256 x, uint256 y) constant internal returns (uint256 z) {
        assert((z = x - y) <= x);
    }
    
    function time() constant returns (uint) {
        return block.timestamp;
    }

    // Each window is 23 hours long so that end-of-window rotates
    // around the clock for all timezones.
    function dayFor(uint timestamp) constant returns (uint) {
        return timestamp < startTime
            ? 0
            : sub(timestamp, startTime) / 24 hours;
    }

    function today() constant returns (uint) {
        return dayFor(time());
    }
    
    /// @dev Contract constructor function sets owner.
     function DelphyICO(address _wallet)
        public
    {
        require (_wallet != 0);
        
        owner = msg.sender;
        wallet = _wallet;
        
        stage = Stages.IcoDeployed;
    }
    
    function setup(address _delphyToken)
        public
        isOwner
        atStage(Stages.IcoDeployed)
    {
        require (_delphyToken != 0);
            // Argument is null.
            
        delphyToken = Token(_delphyToken);
        // Validate token balance
        require (delphyToken.balanceOf(this) == MAX_TOKENS_SOLD);
        
        stage = Stages.IcoSetUp;
    }
    
    function startIco()
        public
        isWallet
        atStage(Stages.IcoSetUp)
    {
        stage = Stages.IcoStarted;
        
        startBlock = block.number;
        startTime = block.timestamp;
    }
    function startTrade()
        public
        isWallet
        atStage(Stages.IcoEnded)
    {
        stage = Stages.TradingStarted;
    }
    
    function bid(address receiver)
        public
        payable
        isValidPayload
        atStage(Stages.IcoStarted)
        returns (uint amount)
    {
        receiver = msg.sender;
        amount = msg.value;
        
        uint dayth = today();
        uint scale = 500;
        uint i = 0;
        
        if (dayth < STEP1_PERIOD) {
        } else if (dayth < STEP2_PERIOD) {
            scale = 470;
            i = 1;
        } else {
            scale = 430;
            i = 2;
        }
        
        uint leftToken = MAX_TOKENS_SOLD - soldTokens;
        uint willsoldToken = amount * scale;
        
        if (willsoldToken > leftToken) {
            willsoldToken = leftToken;
            amount = willsoldToken / scale;
            // Send change back to receiver address. In case of a ShapeShift bid the user receives the change back directly.
            if (!receiver.send(msg.value - amount))
                // Sending failed
                throw;
        }
        
        // Forward funding to ether wallet
        if (amount == 0 || !wallet.send(amount))
            // No amount sent or sending failed
            throw;
        
        bids[i][receiver] += amount;
        totalReceived += amount;
        bidToken[receiver] += willsoldToken;
        soldTokens += willsoldToken;
        
        if (dayth >= STEP3_PERIOD || soldTokens >= MAX_TOKENS_SOLD) {
            finalizeIco();
        }
    }
    
    function claimTokens(address receiver)
        public
        isValidPayload
        atStage(Stages.TradingStarted)
    {
        if (receiver == 0)
            receiver = msg.sender;
        uint tokenCount = bidToken[receiver] ;
        require(tokenCount > 0);
        require((bids[0][receiver] * 500 +
            bids[1][receiver] * 470 + 
            bids[2][receiver] * 430) == tokenCount);
            
        bidToken[receiver] = 0;
        delphyToken.transfer(receiver, tokenCount);
    }
    
    /*
     *  Private functions
     */
    function finalizeIco()
        private
    {
        stage = Stages.IcoEnded;
        delphyToken.transfer(wallet, MAX_TOKENS_SOLD - soldTokens);
        endTime = now;
    }
}