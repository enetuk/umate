pragma solidity >=0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/UmateNFT.sol";

contract TestUmateNFT {
	function testSetPrice() public{
        UmateNFT Umatenft = UmateNFT(DeployedAddresses.UmateNFT());
        Umatenft.setCreatePrice(3);

	}
    function testCreateToken() public {
        // Get the deployed contract
        UmateNFT Umatenft = UmateNFT(DeployedAddresses.UmateNFT());

        // Call getGreeting function in deployed contract
       /// uint create_price = Umatenft.getCreatePrice();

        Umatenft.createToken("http://Umatenet.io/test1.png", 5, true);


        // Assert that the function returns the correct greeting
       // Assert.equal(create_price, "UmateNFT", "UmateNFT test.");
    }
}