import { Contract, ContractRunner } from "ethers";
import { License } from "./types";

const ABI = [
  "function isLicenseValid(uint256 tokenId) view returns (bool)",
  "function getLicenseRemainingTime(uint256 tokenId) view returns (uint256)",
  "function getLicenseInfo(uint256 tokenId) view returns (address owner_, bytes32 contractId_, uint256 expiration_, bool isValid_)",
  "function tokenContractId(uint256 tokenId) view returns (bytes32)",
  "function getLicensesForContract(bytes32 contractId) view returns (uint256[])",
  "function royaltyInfo(uint256 tokenId, uint256 salePrice) view returns (address, uint256)",
  "event LicenseMinted(address indexed to, uint256 indexed tokenId, bytes32 indexed contractId, uint256 expirationTimestamp)",
  "event LicenseExtended(uint256 indexed tokenId, uint256 newExpirationTimestamp)",
  "event LicenseRevoked(uint256 indexed tokenId)",
];

export class LicenseNFTClient {
  private contract: Contract;

  constructor(address: string, runner: ContractRunner) {
    this.contract = new Contract(address, ABI, runner);
  }

  async isValid(tokenId: bigint): Promise<boolean> {
    return this.contract.isLicenseValid(tokenId);
  }

  async getRemainingTime(tokenId: bigint): Promise<bigint> {
    return this.contract.getLicenseRemainingTime(tokenId);
  }

  async getLicense(tokenId: bigint): Promise<License> {
    const [owner, contractId, expiration, isValid] =
      await this.contract.getLicenseInfo(tokenId);
    return { tokenId, owner, contractId, expiration, isValid };
  }

  async getLicensesForContract(contractId: string): Promise<bigint[]> {
    return this.contract.getLicensesForContract(contractId);
  }

  async getRoyaltyInfo(
    tokenId: bigint,
    salePrice: bigint
  ): Promise<{ receiver: string; amount: bigint }> {
    const [receiver, amount] = await this.contract.royaltyInfo(tokenId, salePrice);
    return { receiver, amount };
  }
}
