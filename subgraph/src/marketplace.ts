import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  ContractListed,
  LicensePurchased,
  ListingDelisted,
  ContractRegistered,
  ContractVerified,
} from "../generated/ContractMarketplace/ContractMarketplace";
import { Listing, ContractRegistry } from "../generated/schema";

export function handleContractListed(event: ContractListed): void {
  let id = event.params.listingId.toString();
  let listing = new Listing(id);

  listing.seller          = event.params.seller;
  listing.contractAddress = event.params.contractAddress;
  listing.price           = event.params.price;
  listing.metadata        = event.params.metadata;
  listing.active          = true;
  listing.listedAt        = event.block.timestamp;

  listing.save();
}

export function handleLicensePurchased(event: LicensePurchased): void {
  let id = event.params.listingId.toString();
  let listing = Listing.load(id);
  if (listing == null) return;

  listing.active      = false;
  listing.buyer       = event.params.buyer;
  listing.tokenId     = event.params.tokenId;
  listing.purchasedAt = event.block.timestamp;

  listing.save();
}

export function handleListingDelisted(event: ListingDelisted): void {
  let id = event.params.listingId.toString();
  let listing = Listing.load(id);
  if (listing == null) return;

  listing.active = false;
  listing.save();
}

export function handleContractRegistered(event: ContractRegistered): void {
  let id = event.params.contractId.toHexString();
  let registry = new ContractRegistry(id);

  registry.author       = event.params.author;
  registry.name         = event.params.name;
  registry.version      = event.params.version;
  registry.symbol       = "";
  registry.licensePrice = BigInt.fromI32(0);
  registry.verified     = false;
  registry.isActive     = true;
  registry.totalSales   = BigInt.fromI32(0);
  registry.registeredAt = event.block.timestamp;

  registry.save();
}

export function handleContractVerified(event: ContractVerified): void {
  let id = event.params.contractId.toHexString();
  let registry = ContractRegistry.load(id);
  if (registry == null) return;

  registry.verified = true;
  registry.save();
}
