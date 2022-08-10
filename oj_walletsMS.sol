/SPDX-License-Identifier: MIT

//Using latest compiling version to ensure future stability and maintenance of functions as the lang progresses
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";  


contract jwallet is Ownable {

//Establishing ownership of tokens through an individual owner
//Making a boolean to help represent any address that has owned a token within the wallet; this can be a form of security to see any foreign interactions within the tx's
//Listing the tokens that are in the wallet currently, as well as those to be added to the wallet at a later time

    address private _owner;
    bool private constant has_owned = true;
    bytes32[] public tokenList;

//creating a state variable to assist with the m.s functionality ahead
    bool private constant isApproved = true;
    
    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }
    
    mapping(bytes32 => Token) public tokenMapping;
    mapping(address => mapping(bytes32 => bool)) private active_user;
    mapping(address => mapping(bytes32 => uint256)) public balances;
    mapping(address => bool) internal approval_stat;

    modifier tokenExist(bytes32 ticker){
        require(tokenMapping[ticker].tokenAddress != address(0), "Token does not exist.");
        _;
    }

    modifier minimumBal(bytes32 ticker){
        require(balances[_owner][ticker] > 0);
        _;
    }
    modifier minSig(address ad1, address ad2){
        require(ad1 != address(0) && ad2 != address(0));
        require(ad1 != msg.sender && ad2 != msg.sender);
        require(approval_stat[msg.sender] == true);
        _;
    }


    function addToken(bytes32 ticker, address tokenAddress) onlyOwner external {
        tokenMapping[ticker] = Token(ticker, tokenAddress);
        tokenList.push(ticker);
    }


    function deposit(uint256 amount, bytes32 ticker) tokenExist(ticker) onlyOwner external {
        require(msg.sender == _owner);
        uint256 i_a = balances[msg.sender][ticker];
        IERC20(tokenMapping[ticker].tokenAddress).transferFrom(msg.sender,address(this), amount);
        balances[msg.sender][ticker] = balances[msg.sender][ticker] + (amount);
        active_user[_owner][ticker] = has_owned;
        assert(balances[msg.sender][ticker] == (i_a + amount));
    }


    function withdraw(uint256 amount, bytes32 ticker) tokenExist(ticker) minimumBal(ticker) external {
        require(tokenMapping[ticker].tokenAddress != address(0));
        require(active_user[msg.sender][ticker] = true);
        require(balances[msg.sender][ticker] >= amount, "Balance not sufficient.");
        uint256 past_bal = balances[msg.sender][ticker];
        balances[msg.sender][ticker] = balances[msg.sender][ticker] - (amount);
        IERC20(tokenMapping[ticker].tokenAddress).transfer(msg.sender, amount);
        assert(balances[msg.sender][ticker] == past_bal - amount);
    }


    function withdrawAll(uint256 amount, bytes32 ticker) tokenExist(ticker) minimumBal(ticker) external {
        require(msg.sender == _owner);
        require(tokenMapping[ticker].tokenAddress != address(0));
        require(balances[msg.sender][ticker] >= amount, "Balance not sufficient.");
        require(active_user[_owner][ticker] == true);
        balances[msg.sender][ticker] = balances[msg.sender][ticker] - (amount);
        IERC20(tokenMapping[ticker].tokenAddress).transfer(msg.sender, amount);
        assert(balances[msg.sender][ticker] == 0);
    }

    function tokenTransfer(address to, bytes32 ticker, uint256 amt) tokenExist(ticker) onlyOwner external {
        require(to != address(0));
        _transferTokens(to, ticker, amt);
        IERC20(tokenMapping[ticker].tokenAddress).transferFrom(msg.sender, to, amt);
    }

    function _transferTokens(address to, bytes32 ticker, uint256 amt) tokenExist(ticker) onlyOwner internal {
        require(to != address(0));
        require(to != msg.sender);
        require(balances[to][ticker] > amt);
        uint256 old_owner = balances[msg.sender][ticker];
        uint256 new_owner = balances[to][ticker];
        balances[msg.sender][ticker] = old_owner - amt;
        balances[to][ticker] = new_owner + amt;
        assert(balances[msg.sender][ticker] == old_owner - amt);
        assert(balances[to][ticker] == new_owner + amt);
    }
    
    function any_ownership(bytes32 ticker) external view tokenExist(ticker) returns(bool){
        if(active_user[_owner][ticker] == true){
            return true;
        } else if(balances[_owner][ticker] > 0){
            return false;
        } else{
            return false;
        }   
    }
}
