import { JsonRpcProvider, Wallet, Provider } from "ethers";
import { SDKConfig } from "./types";
import { LicenseNFTClient } from "./LicenseNFTClient";
import { MarketplaceClient } from "./MarketplaceClient";
import { FactoryClient } from "./FactoryClient";

export class ContractHubSDK {
  public readonly nft:         LicenseNFTClient;
  public readonly marketplace: MarketplaceClient;
  public readonly factory:     FactoryClient;

  private constructor(
    nft:         LicenseNFTClient,
    marketplace: MarketplaceClient,
    factory:     FactoryClient
  ) {
    this.nft         = nft;
    this.marketplace = marketplace;
    this.factory     = factory;
  }

  static create(config: SDKConfig): ContractHubSDK {
    const provider: Provider = new JsonRpcProvider(config.rpcUrl);
    const signer = config.privateKey
      ? new Wallet(config.privateKey, provider)
      : undefined;

    const runner = signer ?? provider;

    return new ContractHubSDK(
      new LicenseNFTClient(config.addresses.licenseNFT,  runner),
      new MarketplaceClient(config.addresses.marketplace, runner),
      new FactoryClient(config.addresses.factory,         runner)
    );
  }
}
