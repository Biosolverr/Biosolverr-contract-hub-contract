import { Contract, ContractRunner, parseEther } from "ethers";
import { Listing, PurchaseResult } from "./types";

const ABI = [
  "function listContract(address contractAddress, uint256 price, string metadata) returns (uint256)",
  "function delistContract(uint256 listingId)",
  "function purchaseLicense(uint256 listingId) payable returns (uint256)",
  "function purchaseLicenseWithExpiration(uint256 listingId, uint256 expiration) payable returns (uint256)",
  "function withdrawEarnings()",
  "function withdrawPlatformFees()",
  "function getPendingEarnings(address account) view returns (uint256)",
  "function getListing(uint256 listingId) view returns (address seller, address contractAddress, uint256 price, bool active, string metadata)",
  "function getTotalListings() view returns (uint256)",
  "function platformEthAccrued() view returns (uint256)",
  "function registerContract(string name, string symbol, string version, bytes32 metadataHash, bytes32 sourceHash, uint256 licensePrice) payable",
  "function purchaseLicense(bytes32 contractId)",
  "function rateContract(bytes32 contractId, uint256 rating)",
  "function getAverageRating(bytes32 contractId) view returns (uint256)",
  "function hasPurchased(bytes32 contractId, address buyer) view returns (bool)",
  "function reputation(address) view returns (uint256)",
];

export class MarketplaceClient {
  private contract: Contract;

  constructor(address: string, runner: ContractRunner) {
    this.contract = new Contract(address, ABI, runner);
  }

  // ── Режим А: ETH листинги ──────────────────────────────────────────────────

  async listContract(
    contractAddress: string,
    priceEth: string,
    metadata: string
  ): Promise<bigint> {
    const tx = await this.contract.listContract(
      contractAddress,
      parseEther(priceEth),
      metadata
    );
    const receipt = await tx.wait();
    const event   = receipt.logs.find((l: any) => l.eventName === "ContractListed");
    return event?.args?.listingId ?? BigInt(0);
  }

  async purchaseLicense(
    listingId: bigint,
    priceEth: string
  ): Promise<PurchaseResult> {
    const tx = await (this.contract["purchaseLicense(uint256)"] as any)(
      listingId,
      { value: parseEther(priceEth) }
    );
    const receipt = await tx.wait();
    const event   = receipt.logs.find((l: any) => l.eventName === "LicensePurchased");
    return {
      tokenId: event?.args?.tokenId ?? BigInt(0),
      txHash:  receipt.hash,
    };
  }

  async purchaseLicenseWithExpiration(
    listingId:  bigint,
    priceEth:   string,
    expiration: bigint
  ): Promise<PurchaseResult> {
    const tx = await this.contract.purchaseLicenseWithExpiration(
      listingId,
      expiration,
      { value: parseEther(priceEth) }
    );
    const receipt = await tx.wait();
    const event   = receipt.logs.find((l: any) => l.eventName === "LicensePurchased");
    return {
      tokenId: event?.args?.tokenId ?? BigInt(0),
      txHash:  receipt.hash,
    };
  }

  async getListing(listingId: bigint): Promise<Listing> {
    const [seller, contractAddress, price, active, metadata] =
      await this.contract.getListing(listingId);
    return { listingId, seller, contractAddress, price, metadata, active };
  }

  async getPendingEarnings(account: string): Promise<bigint> {
    return this.contract.getPendingEarnings(account);
  }

  async withdrawEarnings(): Promise<void> {
    const tx = await this.contract.withdrawEarnings();
    await tx.wait();
  }

  // ── Режим Б: ERC20 реестр ──────────────────────────────────────────────────

  async getAverageRating(contractId: string): Promise<bigint> {
    return this.contract.getAverageRating(contractId);
  }

  async hasPurchased(contractId: string, buyer: string): Promise<boolean> {
    return this.contract.hasPurchased(contractId, buyer);
  }

  async getReputation(author: string): Promise<bigint> {
    return this.contract.reputation(author);
  }
}
