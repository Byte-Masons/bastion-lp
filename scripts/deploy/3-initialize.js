async function main() {
  const vaultAddress = '0xc0F4441a1B059eC16a290bbA0158389CCbA07ebE';
  const strategyAddress = '0x01A2dD38f688bC11F09D1Cd6aB3318A292a9EF9F';

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
