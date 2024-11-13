// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Token.sol"; 

import "@openzeppelin/contracts/access/Ownable.sol";

interface IToken {
    function launch(
        address newOwner
    ) external ;
    function 
}

interface IUniswapFactory {
  function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract TokenFactory is Ownable {

    struct TokenInfo {
        address tokenAddress; 
    }

    TokenInfo[] public deployedTokens;
    address public contributionContract;
    mapping(address => bool) public whitelist;

    event TokenDeployed(address tokenAddress,  string name, string symbol, uint256 initialSupply );
    event WhitelistUpdated(address indexed account, bool isWhitelisted);

    constructor() Ownable(msg.sender) {
    }

    IUniswapFactory factory = IUniswapFactory(0xe0b8838e8d73ff1CA193E8cc2bC0Ebf7Cf86F620) ; 
    address pair = factory.getPair(address(this),router.WETH());

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "Caller is not whitelisted");
        _;
    }

    function addWhitelist(address account) external onlyOwner {
        whitelist[account] = true;
        emit WhitelistUpdated(account, true);
    }

    function removeWhitelist(address account) external onlyOwner {
        whitelist[account] = false;
        emit WhitelistUpdated(account, false);
    }

    function deployToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public onlyWhitelisted returns(address _token){
        Token newToken = new Token(name, symbol, initialSupply,address(this)); 
        deployedTokens.push(TokenInfo({
            tokenAddress: address(newToken)
        }));
        // Transfer initial supply to the bonding curve contract
        newToken.transfer(contributionContract, initialSupply);
        emit TokenDeployed(address(newToken),  name, symbol, initialSupply);
        return address(newToken);
    }

    function getDeployedTokens() public view returns (TokenInfo[] memory) {
        return deployedTokens;
    }

    function approve() {
        IToken()
    }
   

    function launch(address token,address owner) external {
      

        IToken(token).launch(owner);
    }
    

    function setContributionContract(address _contract) external onlyOwner{
        contributionContract = _contract ; 
        whitelist[_contract] = true;
    }

}
