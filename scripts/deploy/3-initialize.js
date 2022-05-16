async function main() {
  const vaultAddress = '0x21f95cfF4aa2E1DD8F43c6B581F246E5aA67Fc9c';
  const strategyAddress = '0x60eC371C264Df9d091c2784953c16F2E23C952F3';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);

  await vault.initialize(strategyAddress);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
