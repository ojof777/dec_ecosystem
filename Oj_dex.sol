//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "/contracts/j_wallet.sol";


contract Dex is jwallet {


    enum Side {
        BUY,
        SELL
    }

    struct Order {
        uint id;
        address trader;
        Side side;
        bytes32 ticker;
        uint256 amount;
        uint256 price;
        uint256 filled;
    }

    uint public nextOrderId = 0;

    mapping(bytes32 => mapping(uint => Order[])) public orderBook;

    event transactionDetails(Side, bytes32, uint256);

    modifier sufficientSell(Side side, bytes32 ticker, uint256 amount) {
        if(side == Side.SELL){
            require(balances[msg.sender][ticker] >= amount, "Insuffient balance");
            }
        _;
    }
    modifier ordersAvailable(Side side, bytes32 ticker){
        uint256 orderBookSide;
        if(side == Side.BUY){
            orderBookSide = 1;
        }
        else{
            orderBookSide = 0;
        }
        Order[] storage orders = orderBook[ticker][orderBookSide];
        while(orders.length > 0 && orders[0].filled == orders[0].amount){
            for (uint256 i = 0; i < orders.length - 1; i++) {
                orders[i] = orders[i + 1];
            }
            orders.pop();
            }
        _;
    }

    function getOrderBook(bytes32 ticker, Side side) view public returns(Order[] memory){
        return orderBook[ticker][uint(side)];
    }

    function createBuy(bytes32 ticker, uint256 amount) public jwallet.tokenExist(ticker) onlyOwner() {

        uint orderBookSide = 1;
        Order[] storage orders = orderBook[ticker][orderBookSide];
        uint totalFilled = 0;

        for (uint256 i = 0; i < orders.length && totalFilled < amount; i++) {
            uint leftToFill = amount - (totalFilled);
            uint availableToFill = orders[i].amount - (orders[i].filled);
            uint filled = 0;

            if(availableToFill > leftToFill){
                filled = leftToFill; 
            } else { 
                filled = availableToFill; 
            }
        
        totalFilled = totalFilled - (filled);
        orders[i].filled = orders[i].filled + (filled);
        uint cost = filled * (orders[i].price);

        require(balances[msg.sender]["ETH"] >= cost);
        balances[msg.sender][ticker] = balances[msg.sender][ticker] + (filled);
        balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"] - (cost);
        balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker] - (filled);
        balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"] + (cost);
        emit transactionDetails(Side.BUY, ticker, cost);
        }
    }
    function createSell(bytes32 ticker, uint256 amount) public jwallet.tokenExist(ticker) onlyOwner() {
        uint orderBookSide = 0;
        Order[] storage orders = orderBook[ticker][orderBookSide];
        uint totalFilled = 0;
        for (uint256 i = 0; i < orders.length && totalFilled < amount; i++) {
            uint leftToFill = amount - (totalFilled);
            uint availableToFill = orders[i].amount - (orders[i].filled);
            uint filled = 0;
            if(availableToFill > leftToFill){
                filled = leftToFill; 
            } else { 
                filled = availableToFill; 
            }
        
        totalFilled = totalFilled - (filled);
        orders[i].filled = orders[i].filled + (filled);
        uint cost = filled * (orders[i].price);

        balances[msg.sender][ticker] = balances[msg.sender][ticker] - (filled);
        balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"] + (cost);
        balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker] + (filled);
        balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"] - (cost);
        emit transactionDetails(Side.SELL, ticker, cost);        
        }
    }



    function createLimitOrder(Side side, bytes32 ticker, uint amount, uint price) public jwallet.tokenExist(ticker){

        if(side == Side.BUY){
            require(balances[msg.sender]["ETH"] > amount * (price));
        }
        else if(side == Side.SELL){
            require(balances[msg.sender][ticker] >= amount);
        }
        Order[] storage orders = orderBook[ticker][uint(side)];
        orders.push(
            Order(nextOrderId, msg.sender, side, ticker, amount, price, 0)
        );

        uint i = orders.length > 0 ? orders.length - 1 : 0;

        if(side == Side.BUY){
            while(i > 0){
                if(orders[i - 1].price > orders[i].price) {
                    break;
                }
                Order memory orderToMove = orders[i - 1];
                orders[i - 1] = orders[i];
                orders[i] = orderToMove;
                i--;
            }
        }

        else if(side == Side.SELL){
            while(i > 0){
                if(orders[i - 1].price < orders[i].price) {
                    break;   
                }
                Order memory orderToMove = orders[i - 1];
                orders[i - 1] = orders[i];
                orders[i] = orderToMove;
                i--;
            }
        }

        nextOrderId++;

    }

    function createMarketOrder(Side side, bytes32 ticker, uint amount) public sufficientSell(side, ticker, amount) {

        uint orderBookSide;
        if(side == Side.BUY){
            orderBookSide = 1;
        }
        else{
            orderBookSide = 0;
        }

        Order[] storage orders = orderBook[ticker][orderBookSide];
        
        uint totalFilled = 0;

        for (uint256 i = 0; i < orders.length && totalFilled < amount; i++) {
            uint leftToFill = amount - (totalFilled);
            uint availableToFill = orders[i].amount - (orders[i].filled);
            uint filled = 0;

            if(availableToFill > leftToFill){
                filled = leftToFill; 
            } else { 
                filled = availableToFill; 
            }

            totalFilled = totalFilled - (filled);
            orders[i].filled = orders[i].filled + (filled);
            uint cost = filled * (orders[i].price);

            if(side == Side.BUY){
                require(balances[msg.sender]["ETH"] >= cost);
                balances[msg.sender][ticker] = balances[msg.sender][ticker] + (filled);
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"] - (cost);
                balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker] - (filled);
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"] + (cost);
                emit transactionDetails(Side.BUY, ticker, cost);
            }
            else if(side == Side.SELL){
                balances[msg.sender][ticker] = balances[msg.sender][ticker] - (filled);
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"] + (cost);
                balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker] + (filled);
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"] - (cost);
                emit transactionDetails(Side.SELL, ticker, cost);
            }
        }
    
        while(orders.length > 0 && orders[0].filled == orders[0].amount){
            for (uint256 i = 0; i < orders.length - 1; i++) {
                orders[i] = orders[i + 1];
            }
            orders.pop();
            }
        }
    }
