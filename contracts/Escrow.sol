//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IERC721 {
    function transferFrom(
        address _from,
        address _to,
        uint256 _id
    ) external;
}

contract Escrow {
    //address of smart contract for nft 
    address public nftAddress ; 
    //seller is the address which will recive crypto currency so they must have payable atribute
    address payable public seller ; 
    address public inspector ; 
    address public lender ; 

    modifier onlySeller(){
        require(msg.sender == seller, "only seller can call this method");
        _; 
    }
    modifier onlyBuyer(uint256 _nftId){
        require(msg.sender == buyer[_nftId], "only buyer can call this method");
        _;
    }
    modifier onlyInspector() {
        require(msg.sender == inspector, "Only inspector can call this method");
        _;
    }

    mapping(uint256 => bool) public isListed ; 
    mapping(uint256 => uint256) public purchasePrice;
    mapping(uint256 => uint256) public escrowAmount;
    mapping(uint256 => address) public buyer;
    mapping(uint256 => bool) public inspectionPassed;
    mapping(uint256 => mapping(address => bool)) public approval;

    constructor(address _nftAddress, address payable _seller, address _inspector, address _lender){
        nftAddress = _nftAddress;
        seller = _seller;
        inspector = _inspector;
        lender = _lender;
    }

    /*
    our RealEstate nft contract have transferFrom function from ERC721 zeppelin which he extends        
    so we made IERC721 interface with signature of tranferFrom function which that RealEstate
    contract has, and we can pass address of that contract and call that function
    and then we send nft from sender to escrow account(which is address of this escrow contract)
    and then we with _nftId tell id of nft that we are transfering
    */
    function list(uint256 _nftId,address _buyer, uint256 _purchasePrice, uint256 _escrowAmount)
     public payable onlySeller {
        IERC721(nftAddress).transferFrom(msg.sender, address(this), _nftId); 

        isListed[_nftId] = true ; 
        purchasePrice[_nftId] = _purchasePrice;  
        escrowAmount[_nftId] = _escrowAmount ; 
        buyer[_nftId] = _buyer; 
    }

    // Put Under Contract (only buyer - payable escrow)
    //here will buyer put deposit money which will be store in this escrow contract
    function depositEarnest(uint256 _nftID) public payable onlyBuyer(_nftID) {
        require(msg.value >= escrowAmount[_nftID]);
    }

    //returns balance of ether of this contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    //this function will allow this escrow contract to recive money from lender
    receive() external payable {}

    //Update Inspection Status (only inspector)
    function updateInspectionStatus(uint256 _nftID, bool _passed)
        public
        onlyInspector
    {
        inspectionPassed[_nftID] = _passed;
    }

    //Approve Sale
    function approveSale(uint256 _nftID) public {
        approval[_nftID][msg.sender] = true;
    }

     // Finalize Sale
    // -> Require inspection status (add more items here, like appraisal)
    // -> Require sale to be authorized
    // -> Require funds to be correct amount
    // -> Transfer NFT to buyer
    // -> Transfer Funds to Seller
    function finalizeSale(uint256 _nftID) public {
        require(inspectionPassed[_nftID]);
        require(approval[_nftID][buyer[_nftID]]);
        require(approval[_nftID][seller]);
        require(approval[_nftID][lender]);
        require(address(this).balance >= purchasePrice[_nftID]);

        isListed[_nftID] = false;

        //transfer money to seller
        //this will send money from escrow account(this contract) to seller 
        (bool success, ) = payable(seller).call{value: address(this).balance}("");
        //this will require this transaction before to be successfull
        require(success);

        //transfer ownership to buyer
        IERC721(nftAddress).transferFrom(address(this), buyer[_nftID], _nftID);
    }

     // Cancel Sale (handle earnest deposit)
    // -> if inspection status is not approved, then refund, otherwise send to seller
    function cancelSale(uint256 _nftID) public {
        if (inspectionPassed[_nftID] == false) {
            payable(buyer[_nftID]).transfer(address(this).balance);
        } else {
            payable(seller).transfer(address(this).balance);
        }
    }
}
