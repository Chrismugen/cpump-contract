
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapFactory {
  function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapRouter {
    function WETH() external pure returns (address);
}

contract Token is ERC20, Ownable {
    constructor(string memory name, string memory symbol, uint256 initialSupply,address _whitelist) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
        whitelistedAddresses[_whitelist] = true;
    }

    IUniswapRouter router = IUniswapRouter(0x74F56a7560eF0C72Cf6D677e3f5f51C2D579fF15) ; 
    IUniswapFactory factory = IUniswapFactory(0xe0b8838e8d73ff1CA193E8cc2bC0Ebf7Cf86F620) ; 

    mapping(address => bool) public whitelistedAddresses;
    bool public tradingEnabled = false;



    modifier onlyWhitelisted() {
        require(whitelistedAddresses[msg.sender], "You are not whitelisted");
        _;
    }

    event WhitelistedAddressAdded(address addr);
    event WhitelistedAddressRemoved(address addr);
    event TradingStatusChanged(bool enabled);



     // Function to add an address to the whitelist (only owner can call this)
    function addWhitelistAddress(address addr) public onlyOwner {
        whitelistedAddresses[addr] = true;
        emit WhitelistedAddressAdded(addr);
    }

    // Function to remove an address from the whitelist (only owner can call this)
    function removeWhitelistAddress(address addr) public onlyOwner {
        whitelistedAddresses[addr] = false;
        emit WhitelistedAddressRemoved(addr);
    }

  

     function launch(address newOwner) external onlyWhitelisted {
        tradingEnabled = true;
        transferOwnership(newOwner);
        emit TradingStatusChanged(true);
    }



  // Override the transfer function to prevent transfers if trading is disabled
    // unless it's from/to a liquidity pair or during minting/burning
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual  override {
        super._update(from, to, amount);

        if(!tradingEnabled){
            address pair = factory.getPair(address(this),router.WETH());
            if(to == pair){
                if(!whitelistedAddresses[from]) {
                // Trading must be enabled for non-liquidity-pair transfers         
                require(tradingEnabled, "Trading is currently disabled");
       
                }
            }
        }
        // Allow minting and burning even when trading is disabled
      
    }
}
