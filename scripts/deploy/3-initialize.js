async function main() {
  const vaultAddress = '0xe42C13d35359e8F47b0f6CE7a5583c5907D6854B';
  const strategyAddress = '0xA75a9af9626Bb6eb2684Fc5b5a2348CeBb89a1dA';

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
