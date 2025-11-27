const { ethers } = require("hardhat");

async function main() {
  const BridgeFlowHub = await ethers.getContractFactory("BridgeFlowHub");
  const bridgeFlowHub = await BridgeFlowHub.deploy();

  await bridgeFlowHub.deployed();

  console.log("BridgeFlowHub contract deployed to:", bridgeFlowHub.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
