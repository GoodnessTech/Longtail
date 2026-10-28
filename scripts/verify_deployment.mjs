import fs from 'fs';

const raw = fs.readFileSync('contracts/broadcast/DeployBohrTestnet.s.sol/968/run-latest.json', 'utf-8');
const receipt = JSON.parse(raw);

console.log('Total transactions:', receipt.transactions.length);
receipt.transactions.forEach((tx, idx) => {
  console.log(`[Tx ${idx + 1}]`);
  console.log('Contract:', tx.contractName || 'Call');
  console.log('Function:', tx.function || 'deploy');
  console.log('Address:', tx.contractAddress);
  console.log('Tx Hash:', tx.hash);
  console.log('Gas Used:', tx.gas || 'N/A');
  console.log('------------------------------------');
});
