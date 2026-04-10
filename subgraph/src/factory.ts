import { BigInt } from "@graphprotocol/graph-ts";
import {
  ContractDeployed,
  ImplementationRegistered,
} from "../generated/ContractFactory/ContractFactory";
import { Deployment, Implementation } from "../generated/schema";

export function handleContractDeployed(event: ContractDeployed): void {
  let id = event.params.clone.toHexString();
  let dep = new Deployment(id);

  dep.contractId  = event.params.contractId;
  dep.deployer    = event.params.deployer;
  dep.version     = event.params.version;
  dep.deployedAt  = event.block.timestamp;
  dep.txHash      = event.transaction.hash;

  dep.save();
}

export function handleImplementationRegistered(
  event: ImplementationRegistered
): void {
  let id =
    event.params.contractId.toHexString() +
    "-" +
    event.params.version.toString();

  let impl = new Implementation(id);
  impl.contractId   = event.params.contractId;
  impl.address      = event.params.implementation;
  impl.version      = event.params.version;
  impl.metadata     = event.params.metadata;
  impl.deprecated   = false;
  impl.registeredAt = event.block.timestamp;

  impl.save();
}
