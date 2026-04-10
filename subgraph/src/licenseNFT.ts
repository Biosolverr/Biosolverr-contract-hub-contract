import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  LicenseMinted,
  LicenseExtended,
  LicenseRevoked,
} from "../generated/LicenseNFT/LicenseNFT";
import { License } from "../generated/schema";

export function handleLicenseMinted(event: LicenseMinted): void {
  let id = event.params.tokenId.toString();
  let license = new License(id);

  license.owner       = event.params.to;
  license.contractId  = event.params.contractId;
  license.expiration  = event.params.expirationTimestamp;
  license.metadataURI = "";
  license.valid       = true;
  license.mintedAt    = event.block.timestamp;
  license.mintTx      = event.transaction.hash;

  license.save();
}

export function handleLicenseExtended(event: LicenseExtended): void {
  let id = event.params.tokenId.toString();
  let license = License.load(id);
  if (license == null) return;

  license.expiration = event.params.newExpirationTimestamp;
  license.valid      = true;
  license.save();
}

export function handleLicenseRevoked(event: LicenseRevoked): void {
  let id = event.params.tokenId.toString();
  let license = License.load(id);
  if (license == null) return;

  license.valid = false;
  license.save();
}
