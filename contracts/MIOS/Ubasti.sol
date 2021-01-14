// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./token/ERC1155/ERC1155.sol";
import "./MIOS.sol";

contract Ubasti is ERC1155{

    string public name = "Ubasti";
    string public symbol = "UBASTI";

    MIOS m;
    address public admin;
    mapping(address=>uint) public creators;

    uint public MIOSToMint;
    uint public tokenIndex;

    address[] public stakingPools;
    uint[] public stakingPoolShares;
    uint public totalShares;

    modifier adminOnly{
        require(msg.sender==admin,"Account must be Admin");
        _;
    }

    modifier creatorsOnly (uint amount){
        require(creators[msg.sender]>=amount,"Account must be a Creator");
        creators[msg.sender] = creators[msg.sender].sub(amount);
        _;
    }

    mapping(uint => uint[]) private specialRequirements;

    function getSpecialRequirements(uint tokenID) public view returns(uint[] memory){
        return(specialRequirements[tokenID]);
    }

    function setContractURI(string memory newContractURI) public adminOnly{
        contractURI = newContractURI;
    }

    function changeAdmin(address newAdmin) public adminOnly{
        admin = newAdmin;
    }

    event creatorAuthroized(address creator, uint amount);
    event creatorDeauthorized(address creator);

    function authorizeCreators(address[] memory creatorsToAdd, uint[] memory amounts) public adminOnly{
        for(uint i = 0; i<creatorsToAdd.length;i++){
            creators[creatorsToAdd[i]] = amounts[i];
            emit creatorAuthroized(creatorsToAdd[i],amounts[i]);
        }
    }

    function deathorizeCreators(address[] memory creatorsToRemove) public adminOnly{
        for(uint i = 0; i<creatorsToRemove.length;i++){
            creators[creatorsToRemove[i]] = 0;
            emit creatorDeauthorized(creatorsToRemove[i]);
        }
    }

    constructor() ERC1155() public {
        admin = msg.sender;
        m = new MIOS();
        contractURI = "https://ipfs.io/ipfs/QmW3mGbYZcazw2koj6kWfiCgWKETGWA2WgKYqiQ7ZLnHTq";
    }

    function create(uint amount,string memory URI) public creatorsOnly(1) {
        _mint(msg.sender,tokenIndex,amount,"");
        _tokenURIs[tokenIndex] = URI;
        tokenIndex++;
        MIOSToMint++;
    }

    function createSet(uint[] memory amounts,string[] memory URIs) public creatorsOnly(amounts.length){
        require(amounts.length==URIs.length,"must provide equal length arrays");

        uint length = amounts.length;
        uint[] memory ids = new uint[](length);
        for (uint i=0;i<length;i++){
            ids[i] = tokenIndex+i;
            _tokenURIs[ids[i]] = URIs[i];
        }

        _mintBatch(msg.sender,ids,amounts,"");

        tokenIndex+=length;
        MIOSToMint += length;
    }

    event specialCreated(uint specialID);

    function createSetWithSpecial(uint[] memory amounts, uint[] memory required,string[] memory URIs,string memory specialURI) public creatorsOnly(amounts.length+1){
        require(amounts.length==required.length,"must provide equal length arrays");
        require(required.length==URIs.length,"must provide equal length arrays");
        require(amounts.length>0,"set must contain at least 1 card");

        uint length = amounts.length;
        uint[] memory ids = new uint[](length);

       for (uint i=0;i<length;i++){
            ids[i] = tokenIndex+i;
            _tokenURIs[ids[i]] = URIs[i];
        }

        _mintBatch(msg.sender,ids,amounts,"");

        uint specialID = tokenIndex+length;

        specialRequirements[specialID] = required;

        _mint(msg.sender,specialID,0,"");
        _tokenURIs[specialID] = specialURI;
        emit specialCreated(specialID);

        tokenIndex+=length+1;
        MIOSToMint += length+1;
    }

    function mintSpecial(uint tokenID,uint amount) public {
        uint length = specialRequirements[tokenID].length;
        require(length>0, "This token ID is not a special");

        for(uint i = 0;i<length;i++){
            uint subID = tokenID-length+i;
            uint requiredAmount = specialRequirements[tokenID][i];
            _burn(msg.sender,subID,requiredAmount.mul(amount));
        }

        _mint(msg.sender,tokenID,amount,"");
    }

    function burnSpecial(uint tokenID,uint amount) public {
        uint length = specialRequirements[tokenID].length;
        require(length>0, "This token ID is not a special");

        for(uint i = 0;i<length;i++){
            uint subID = tokenID-length+i;
            uint requiredAmount = specialRequirements[tokenID][i];
            _mint(msg.sender,subID,requiredAmount.mul(amount),"");
        }

        _burn(msg.sender,tokenID,amount);
    }

    function mintMIOS() public {
        require(totalShares>0,"Staking Pools Not Added Yet");
        uint toMint = 100*MIOSToMint*10**18;
        uint numPools = stakingPools.length;
        uint minterReward = toMint/1000;

        for(uint i=0;i<numPools;i++){
            uint amountToMint = (toMint.mul(stakingPoolShares[i])).div(totalShares);
            m.mintMIOS(stakingPools[i],amountToMint);
        }

        m.mintMIOS(msg.sender,minterReward);
        MIOSToMint = 0;
    }

    function setStakingPools(address[] memory _stakingPools, uint[] memory _stakingPoolShares) public adminOnly{
        require(_stakingPools.length==_stakingPoolShares.length,"must provide equal length arrays");
        totalShares = 0;
        stakingPools = _stakingPools;
        stakingPoolShares = _stakingPoolShares;

        for(uint i = 0; i<_stakingPools.length;i++){
            totalShares = totalShares.add(stakingPoolShares[i]);
        }
    }

    function addStakingPool(address pool, uint shares) public adminOnly{
        stakingPools.push(pool);
        stakingPoolShares.push(shares);
        totalShares = totalShares.add(shares);
    }

    function removeStakingPool(uint index) public adminOnly{
        totalShares = totalShares.sub(stakingPoolShares[index]);
        stakingPoolShares[index] = 0;
    }

    function stakingPoolLength() public view returns (uint){
        return stakingPools.length;
    }
}
