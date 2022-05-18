async function main() {
  const vaultAddress = '0xe42C13d35359e8F47b0f6CE7a5583c5907D6854B';
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);
  await vault.depositAll();
  console.log('deposit complete');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
