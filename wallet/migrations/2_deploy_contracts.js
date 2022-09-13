const J_Wallet = artifacts.require("J_Wallet");
const J_Dex = artifacts.require("J_Dex");


module.exports = function(deployer) {
  deployer.deploy(J_Wallet);
  deployer.deploy(J_Dex);
};
