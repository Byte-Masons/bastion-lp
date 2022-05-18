async function main() {
  const vaultAddress = '0xe42C13d35359e8F47b0f6CE7a5583c5907D6854B';
  const ERC20 = await ethers.getContractFactory('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');
  const wantAddress = '0x0039f0641156cac478b0DebAb086D78B66a69a01';
  const want = await ERC20.attach(wantAddress);
  await want.approve(vaultAddress, ethers.utils.parseEther('9999999999999999999999'));
  console.log('want approved');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
