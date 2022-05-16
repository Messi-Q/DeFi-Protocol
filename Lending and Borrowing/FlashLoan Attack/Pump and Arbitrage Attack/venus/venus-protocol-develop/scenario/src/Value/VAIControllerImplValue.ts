import {Event} from '../Event';
import {World} from '../World';
import {VAIControllerImpl} from '../Contract/VAIControllerImpl';
import {
  getAddressV
} from '../CoreValue';
import {
  AddressV,
  Value
} from '../Value';
import {Arg, Fetcher, getFetcherValue} from '../Command';
import {getVAIControllerImpl} from '../ContractLookup';

export async function getVAIControllerImplAddress(world: World, vaicontrollerImpl: VAIControllerImpl): Promise<AddressV> {
  return new AddressV(vaicontrollerImpl._address);
}

export function vaicontrollerImplFetchers() {
  return [
    new Fetcher<{vaicontrollerImpl: VAIControllerImpl}, AddressV>(`
        #### Address

        * "VAIControllerImpl Address" - Returns address of vaicontroller implementation
      `,
      "Address",
      [new Arg("vaicontrollerImpl", getVAIControllerImpl)],
      (world, {vaicontrollerImpl}) => getVAIControllerImplAddress(world, vaicontrollerImpl),
      {namePos: 1}
    )
  ];
}

export async function getVAIControllerImplValue(world: World, event: Event): Promise<Value> {
  return await getFetcherValue<any, any>("VAIControllerImpl", vaicontrollerImplFetchers(), world, event);
}
