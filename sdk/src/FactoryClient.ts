import { Contract, ContractRunner } from "ethers";
import { DeployResult } from "./types";

const ABI = [
  "function deployContract(bytes32 contractId, uint256 licenseTokenId) returns (address)",
  "function deployContractWithVersion(bytes32 contractId, uint256 licenseTokenId, uint256 version) returns (address)",
  "function getActiveImplementation(bytes32 contractId) view returns (address implementation, uint256 version, string metadata)",
  "function getInstanceContractId(address instance) view returns (bytes32)",
  "function getUserDeployments(address user, bytes32 contractId) view returns (address[])",
  "function isLicenseUsed(uint256 tokenId) view returns (bool)",
  "function getImplementationInfo(bytes32 contractId, uint256 version) view returns (address, uint256, bool, string)",
];

export class FactoryClient {
  private contract: Contract;

  constructor(address: string, runner: ContractRunner) {
    this.contract = new Contract(address, ABI, runner);
  }

  async deployContract(
    contractId:     string,
    licenseTokenId: bigint
  ): Promise<DeployResult> {
    const tx      = await this.contract.deployContract(contractId, licenseTokenId);
    const receipt = await tx.wait();
    const event   = receipt.logs.find((l: any) => l.eventName === "ContractDeployed");
    return {
      clone:  event?.args?.clone ?? "",
      txHash: receipt.hash,
    };
  }

  async deployContractWithVersion(
    contractId:     string,
    licenseTokenId: bigint,
    version:        bigint
  ): Promise<DeployResult> {
    const tx      = await this.contract.deployContractWithVersion(
      contractId, licenseTokenId, version
    );
    const receipt = await tx.wait();
    const event   = receipt.logs.find((l: any) => l.eventName === "ContractDeployed");
    return {
      clone:  event?.args?.clone ?? "",
      txHash: receipt.hash,
    };
  }

  async getActiveImplementation(contractId: string): Promise<{
    implementation: string;
    version:        bigint;
    metadata:       string;
  }> {
    const [implementation, version, metadata] =
      await this.contract.getActiveImplementation(contractId);
    return { implementation, version, metadata };
  }

  async getUserDeployments(user: string, contractId: string): Promise<string[]> {
    return this.contract.getUserDeployments(user, contractId);
  }

  async isLicenseUsed(tokenId: bigint): Promise<boolean> {
    return this.contract.isLicenseUsed(tokenId);
  }
}
