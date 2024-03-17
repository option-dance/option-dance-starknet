use serde::Serde;
use array::ArrayTrait;
use traits::Into;
use traits::TryInto;
use option::OptionTrait;
use result::ResultTrait;

use debug::PrintTrait;

use optiondance::libraries::erc20::{IERC20Dispatcher, IERC20DispatcherTrait, ERC20};
use optiondance::otoken::{IOtokenDispatcher, IOtokenDispatcherTrait, Otoken};
use optiondance::tests::test_utils::{account};

use starknet::{get_contract_address, get_caller_address, deploy_syscall, ClassHash, contract_address_const, ContractAddress, contract_address_to_felt252};

const P: felt252 = 80;
const o: felt252 = 111;



fn deploy_mockerc20(name: felt252, symbol: felt252, decimals: u8) ->  (IERC20Dispatcher, ContractAddress) {
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    Serde::serialize(@name, ref constructor_args);
    Serde::serialize(@symbol, ref constructor_args);
    Serde::serialize(@decimals, ref constructor_args);

    let (address, _) = deploy_syscall(ERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_args.span(), false).unwrap();
    return (IERC20Dispatcher { contract_address: address },   address );
}

fn set_caller_as_zero() {
    starknet::testing::set_contract_address(contract_address_const::<0>());
}


#[test]
#[available_gas(3000000)]
fn test_deploy_mock_erc20() {
    let (usdc, _) = deploy_mockerc20('USDC', 'USDC', 6);
    assert(usdc.name() == 'USDC', 'name');
    assert(usdc.symbol() == 'USDC', 'symbol');
    assert(usdc.decimals() == 6, 'symbol');
}



#[test]
#[available_gas(30000000)]
fn test_deploy_otoken() {

    let (usdc, usdc_address) = deploy_mockerc20('USDC', 'USDC', 6);
    let (wbtc, wbtc_address) = deploy_mockerc20('WBTC', 'WBTC', 8);

    // deploy otoken impl contract
    let mut calldata = Default::default();

    let underlying_asset = wbtc_address;
    let quote_asset = usdc_address;
    let strike = u256 {high: 0, low: 3000000000000};
    let expiry_timestamp:felt252 = 1671840000;
    let option_type = P;
    let token_type = o;
    Serde::serialize(@account(1), ref calldata);
    Serde::serialize(@underlying_asset, ref calldata);
    Serde::serialize(@quote_asset, ref calldata);
    Serde::serialize(@strike, ref calldata);
    Serde::serialize(@expiry_timestamp, ref calldata);
    Serde::serialize(@option_type, ref calldata);
    Serde::serialize(@token_type, ref calldata);

    
    let (address, _) = deploy_syscall(Otoken::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false).unwrap();
    let otoken_impl =  IOtokenDispatcher { contract_address: address  };
    assert(otoken_impl.owner() == account(1),  'wrong otoken owner' );
    assert(otoken_impl.name() == 'oWBTC_30000P_USDC_24_12_2022',  'wrong otoken name' );
}