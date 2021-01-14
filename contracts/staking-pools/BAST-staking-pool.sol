pragma solidity ^0.8.0;

abstract contract ERC20 {
    function balanceOf(address who) public view virtual returns (uint256);
    function transfer(address to, uint256 value) public virtual returns (bool);
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool);
}



contract BastStakingPool{
    uint public start; // stake start
    uint public end; // stake end

    address public BAST;
    address public MIOS;

    event Deposit();
    event Withdrawal();
    constructor (address _BAST, uint depositingPeriod, uint stakingPeriod) {
        BAST = _BAST;
        start = block.timestamp + depositingPeriod;
        end = block.timestamp + depositingPeriod + stakingPeriod;
    }

    mapping(address => uint) public shares;
    uint public totalShares;
    function deposit(uint amount) public{
        require(block.timestamp<=start,"Depositing period is over, staking Period has begun");
        shares[msg.sender]+=amount;
        totalShares += amount;

        ERC20(BAST).transferFrom(msg.sender,address(this),amount);
    }

    function withdraw() public{
        uint MIOSAmount = MIOSBalance()*shares[msg.sender]/totalShares;

        ERC20(MIOS).transfer(msg.sender,MIOSAmount);
        ERC20(BAST).transfer(msg.sender,shares[msg.sender]);

        totalShares -= shares[msg.sender];
        shares[msg.sender] = 0;
    }

    function MIOSBalance() public returns(uint){
        return(ERC20(MIOS).balanceOf(address(this)));
    }
}
