import { BigNumberish } from "ethers";

export interface SDKConfig {
  rpcUrl: string;
  privateKey?: string;         // опционально — только для write операций
  addresses: {
    licenseNFT:   string;
    factory:      string;
    marketplace:  string;
  };
}

export interface License {
  tokenId:    bigint;
  owner:      string;
  contractId: string;          // bytes32 hex
  expiration: bigint;          // 0 = бессрочная
  isValid:    boolean;
}

export interface Listing {
  listingId:       bigint;
  seller:          string;
  contractAddress: string;
  price:           bigint;
  metadata:        string;
  active:          boolean;
}

export interface ContractRegistryEntry {
  contractId:   string;
  author:       string;
  name:         string;
  version:      string;
  licensePrice: bigint;
  verified:     boolean;
  isActive:     boolean;
  totalSales:   bigint;
}

export interface DeployResult {
  clone:   string;
  txHash:  string;
}

export interface PurchaseResult {
  tokenId: bigint;
  txHash:  string;
}
