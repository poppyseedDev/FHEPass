import { toBufferBE } from "bigint-buffer";
import { ethers } from "hardhat";

export const mineNBlocks = async (n: number) => {
  for (let index = 0; index < n; index++) {
    await ethers.provider.send("evm_mine");
  }
};

export const bigIntToBytes64 = (value: bigint) => {
  return new Uint8Array(toBufferBE(value, 64));
};

export const bigIntToBytes128 = (value: bigint) => {
  return new Uint8Array(toBufferBE(value, 128));
};

export const bigIntToBytes256 = (value: bigint) => {
  return new Uint8Array(toBufferBE(value, 256));
};
