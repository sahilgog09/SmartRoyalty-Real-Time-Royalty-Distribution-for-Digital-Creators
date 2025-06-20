const hre = require("hardhat");

async function main() {
  const SmartRoyalty = await hre.ethers.getContractFactory("SmartRoyalty");
  const royalty = await SmartRoyalty.deploy();
  await royalty.deployed();

  console.log("SmartRoyalty deployed to:", royalty.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
