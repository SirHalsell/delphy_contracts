pragma solidity 0.4.10;


/// @title Abstract token contract - Functions to be implemented by token contracts.
contract Token {
    function transfer(address to, uint256 value) returns (bool success);
    function transferFrom(address from, address to, uint256 value) returns (bool success);
    function approve(address spender, uint256 value) returns (bool success);

    // This is not an abstract function, because solc won't recognize generated getter functions for public variables as functions.
    function totalSupply() constant returns (uint256 supply) ;
    function balanceOf(address owner) constant returns (uint256 balance);
    function allowance(address owner, address spender) constant returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract DelphyICO {
    /*
     *  Events
     */
    event BuySubmission(address indexed sender, uint256 amount);
    
    /*
     *  Constants
     */
    uint constant public STEP1_ENDDAY = 2 days;
    uint constant public STEP2_ENDDAY = 6 days;
    uint constant public STEP3_ENDDAY = 13 days;
    
    uint constant public MAX_TOKENS_SOLD = 5000000 * 10**18; // 5M
    
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
    uint public endBlock;
    uint public etherReceived;
    uint public tokenSolded;
    mapping (address => uint)[3] public buys;
    mapping (address => uint) public tokens;
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

    function dayFor(uint timestamp) constant returns (uint) {
        return timestamp < startTime
            ? 0
            : sub(timestamp, startTime) / 24 hours;
    }

    function today() constant returns (uint) {
        return dayFor(time());
    }
    
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
    
    function buy()
        public
        payable
        isValidPayload
        atStage(Stages.IcoStarted)
        returns (uint amount)
    {
        address receiver = msg.sender;
        amount = msg.value;
        
        uint dayth = today();
        uint scale = 500;
        uint i = 0;
        
        if (dayth < STEP1_ENDDAY) {
        } else if (dayth < STEP2_ENDDAY) {
            scale = 470;
            i = 1;
        } else {
            scale = 430;
            i = 2;
        }
        
        uint leftToken = MAX_TOKENS_SOLD - tokenSolded;
        uint willsoldToken = amount * scale;
        
        if (willsoldToken > leftToken) {
            willsoldToken = leftToken;
            amount = willsoldToken / scale;
            // Send change back to receiver address. In case of a ShapeShift bid the user receives the change back directly.
            require(receiver.send(msg.value - amount));
        }
        
        // Forward funding to ether wallet
        require (amount != 0 && wallet.send(amount));
        
        buys[i][receiver] += amount;
        etherReceived += amount;
        tokens[receiver] += willsoldToken;
        tokenSolded += willsoldToken;
        
        if (dayth >= STEP3_ENDDAY || tokenSolded >= MAX_TOKENS_SOLD) {
            finalizeIco();
        }
    }
    
    function claimTokens()
        public
        isValidPayload
        atStage(Stages.TradingStarted)
    {
        address receiver = msg.sender;
        uint tokenCount = tokens[receiver] ;
        require(tokenCount > 0);
        require((buys[0][receiver] * 500 +
            buys[1][receiver] * 470 + 
            buys[2][receiver] * 430) == tokenCount);
            
        tokens[receiver] = 0;
        delphyToken.transfer(receiver, tokenCount);
    }
    
    /*
     *  Private functions
     */
    function finalizeIco()
        private
    {
        stage = Stages.IcoEnded;
        delphyToken.transfer(wallet, MAX_TOKENS_SOLD - tokenSolded);
        endBlock = block.number;
    }
}