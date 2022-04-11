const UmateNFT = artifacts.require("UmateNFT");

module.exports = function(deployer) {
  deployer.deploy(UmateNFT);
};