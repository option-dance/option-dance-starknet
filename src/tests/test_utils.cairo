use starknet::{ContractAddress, contract_address_const};
use optiondance::libraries::erc20::{IERC20Dispatcher, IERC20DispatcherTrait, ERC20};



fn account(id: felt252) -> ContractAddress {
    if id == 1 {
        return contract_address_const::<0x47a707C5D559CE163D1919b66AAdC2D00686f563>();
    } else if id == 2 {
        return contract_address_const::<0x47a707C5D559CE163D1919b66AAdC2D00686f564>();
    } else if id == 3 {
        return contract_address_const::<0x47a707C5D559CE163D1919b66AAdC2D00686f565>();
    }
    return contract_address_const::<0x47a707C5D559CE163D1919b66AAdC2D00686f566>();
}