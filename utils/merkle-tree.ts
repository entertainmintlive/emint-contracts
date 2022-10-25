import { hexlify, keccak256, solidityPack } from 'ethers/lib/utils';
import { MerkleTree } from 'merkletreejs';

const ALICE = '0x5dad7600c5d89fe3824ffa99ec1c3eb8bf3b0501';
const BOB = '0x3440326f551b8a7ee198cee35cb5d517f2d296a2';
const CAROL = '0xacfb09713f4f9cc14aa498cbf844b94a27da64ff';
const DAN = '0x8e0614adcffe0315af614f414ab60c6230bdc988';

const allowlist: string[] = [ALICE, BOB, CAROL, DAN];

const leaves = allowlist.map((address: string) => {
  return hexlify(address);
});

const tree = new MerkleTree(leaves, keccak256, {
  hashLeaves: true,
  sortPairs: true,
});

const leaf = keccak256(hexlify(process.argv[2]));

console.log('Tree root: ', tree.getHexRoot());
console.log('Proof: ', tree.getHexProof(leaf));
