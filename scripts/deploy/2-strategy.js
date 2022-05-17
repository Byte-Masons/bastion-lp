const hre = require('hardhat');

async function main() {
  const vaultAddress = '0xe42C13d35359e8F47b0f6CE7a5583c5907D6854B';

  const Strategy = await ethers.getContractFactory('ReaperStrategyBastionLP');
  const treasuryAddress = '0x17D099fc623bd06CFE4861d874704Af184773c75';
  const paymentSplitterAddress = '0x65E45D2f3f43b613416614c73f18fDD3AA2b8391';
  const strategist1 = '0x1E71AEE6081f62053123140aacC7a06021D77348';
  const strategist2 = '0x81876677843D00a7D792E1617459aC2E93202576';
  const strategist3 = '0x1A20D7A31e5B3Bc5f02c8A146EF6f394502a10c4';
  const superAdmin = '0x62D153b7AEd8F7485bA2B5722048869b0E3FF2fA';
  const admin = '0xB2227B8FDd8D5D2EC7532F56bE08c80FaCdB7cd3';
  const guardian = '0xc3642Be9A8d957B48F825c9436eC18F98A10DE03';

  const strategy = await hre.upgrades.deployProxy(
    Strategy,
    [
      vaultAddress,
      [treasuryAddress, paymentSplitterAddress],
      [strategist1, strategist2, strategist3],
      [superAdmin, admin, guardian],
    ],
    {kind: 'uups', timeout: 0},
  );

  await strategy.deployed();
  console.log('Strategy deployed to:', strategy.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
