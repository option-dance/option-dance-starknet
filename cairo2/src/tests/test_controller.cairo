use array::ArrayTrait;
use serde::Serde;
use traits::Into;
use traits::TryInto;
use option::OptionTrait;
use result::ResultTrait;

use debug::PrintTrait;

use optiondance::libraries::erc20::{IERC20Dispatcher, IERC20DispatcherTrait, ERC20};
use optiondance::oracle::{IOracleDispatcher, IOracleDispatcherTrait, Oracle};
use optiondance::otoken::{IOtokenDispatcher, IOtokenDispatcherTrait, Otoken};
use optiondance::controller::{IControllerDispatcher, IControllerDispatcherTrait, Controller};
use optiondance::tests::test_utils::{account};

use starknet::{
    get_contract_address, get_caller_address, deploy_syscall, ClassHash, contract_address_const,
    ContractAddress, contract_address_to_felt252,
    testing::{
        set_block_timestamp, set_contract_address, set_account_contract_address, set_caller_address
    }
};

const P: felt252 = 80;
const o: felt252 = 111;
const expiry_timestamp: u64 = 1671868800;

fn deploy_mockerc20(
    name: felt252, symbol: felt252, decimals: u8
) -> (IERC20Dispatcher, ContractAddress) {
    let mut calldata: Array<felt252> = ArrayTrait::new();
    Serde::serialize(@name, ref calldata);
    Serde::serialize(@symbol, ref calldata);
    Serde::serialize(@decimals, ref calldata);
    let (address, _) = deploy_syscall(
        ERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();
    return (IERC20Dispatcher { contract_address: address }, address);
}

fn set_caller_as_zero() {
    starknet::testing::set_contract_address(contract_address_const::<0>());
}


#[test]
#[available_gas(300000000)]
fn test_deploy_controller() {
    //deploy mock usdc and wbtc
    let (usdc, usdc_address) = deploy_mockerc20('USDC', 'USDC', 6);
    let (wbtc, wbtc_address) = deploy_mockerc20('WBTC', 'WBTC', 8);

    let account1 = account(1);
    let account2 = account(2);

    let otoken_impl_class_hash: ClassHash = Otoken::TEST_CLASS_HASH.try_into().unwrap();

    // deploy oracle
    let mut calldata: Array<felt252> = ArrayTrait::new();
    Serde::serialize(@account1, ref calldata);
    Serde::serialize(@account1, ref calldata);
    calldata.append(1800);

    let (oracle_address, _) = deploy_syscall(
        Oracle::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    // deploy controller
    let owner = account(1);
    set_caller_address(owner);
    let mut calldata = ArrayTrait::new();
    Serde::serialize(@owner, ref calldata);
    Serde::serialize(@otoken_impl_class_hash, ref calldata);
    Serde::serialize(@oracle_address, ref calldata);
    let (controller_addr, _) = deploy_syscall(
        Controller::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();
    let controller = IControllerDispatcher { contract_address: controller_addr };

    assert(controller.get_oracle() == oracle_address, 'wrong oracle');
    assert(controller.owner() == owner, 'wrong owner');

    // test create instrument
    set_contract_address(owner);
    controller.allow_underlying_asset(wbtc_address, true);
    controller.allow_quote_asset(usdc_address, true);
    let mut res = controller
        .create_instrument(
            wbtc_address, usdc_address, u256 { high: 0, low: 3000000000000 }, expiry_timestamp.into(), 80
        );

    let optiontoken = IOtokenDispatcher { contract_address: res.option_token };
    let writertoken = IOtokenDispatcher { contract_address: res.writer_token };
    assert(optiontoken.owner() == controller_addr, 'wrong otoken owner');
    assert(optiontoken.name() == 'oWBTC_30000P_USDC_24_12_2022', optiontoken.name());
    assert(optiontoken.symbol() == 'oWBTC_30000P_USDC_24_12_2022', optiontoken.symbol());

    assert(writertoken.owner() == controller_addr, 'wrong wtoken owner');
    assert(writertoken.name() == 'wWBTC_30000P_USDC_24_12_2022', writertoken.name());
    assert(writertoken.symbol() == 'wWBTC_30000P_USDC_24_12_2022', writertoken.symbol());

    // mint 30000 USDC to test account1
    assert(usdc.balance_of(account1) == 0, 'usdc before balance invalid');
    assert(optiontoken.balance_of(account1) == 0, 'optiontoken balance invalid');
    assert(writertoken.balance_of(account1) == 0, 'writertoken balance invalid');
    usdc.mint(account1, 30001000000);
    assert(usdc.balance_of(account1) == 30001000000, 'invalid');

    // set caller to account1
    set_caller_address(account1);
    set_contract_address(account1);
    // account1 approve 30000 USDC, call mintOption method, to send 30000 usdc to pool and mint 1 option, 
    usdc.approve(controller.contract_address, 30001000000);
    // transfer 1 usdc to controller
    usdc.transfer(controller_addr, 1000000);
    assert(usdc.balance_of(controller_addr) == 1000000, 'usdc of controller invalid');
    assert(controller.get_pool_balance(usdc_address) == 0, 'pool balance usdc invalid');

    controller.mint_option(optiontoken.contract_address, 100000000);
    assert(usdc.balance_of(account1) == u256 { low: 0, high: 0 }, 'usdc after balance invalid');
    assert(usdc.balance_of(controller_addr) == 30001000000, 'usdc of controller invalid');
    assert(controller.get_pool_balance(usdc_address) == 30000000000, 'pool balance usdc invalid');

    assert(optiontoken.balance_of(account1) == 100000000, 'optiontoken balance invalid');
    assert(writertoken.balance_of(account1) == 3000000000000, 'writertoken balance invalid');
    assert(optiontoken.total_supply() == 100000000, 'optiontoken totalsupply invalid');
    assert(writertoken.total_supply() == 3000000000000, 'writertoken totalsupply invalid');


    // test close position
    optiontoken.approve(controller.contract_address, 100000000);
    writertoken.approve(controller.contract_address, 3000000000000);

    // first close half of total position size
    controller.close_position(optiontoken.contract_address, 50000000);
    assert(usdc.balance_of(account1) == 15000000000, 'usdc after balance invalid');
    assert(usdc.balance_of(controller_addr) == 15001000000, 'usdc of controller invalid');
    assert(controller.get_pool_balance(usdc_address) == 15000000000, 'pool balance usdc invalid');

    assert(optiontoken.balance_of(account1) == 50000000, 'optiontoken balance invalid');
    assert(writertoken.balance_of(account1) == 1500000000000, 'writertoken balance invalid');
    assert(optiontoken.balance_of(controller.contract_address) == 0, 'optiontoken balance invalid');
    assert(writertoken.balance_of(controller.contract_address) == 0, 'writertoken balance invalid');
    assert(optiontoken.total_supply() == 50000000, 'optiontoken totalsupply invalid');
    assert(writertoken.total_supply() == 1500000000000, 'writertoken totalsupply invalid');

    // then close another half of total position size
    controller.close_position(optiontoken.contract_address, 50000000);
    assert(usdc.balance_of(account1) == 30000000000, 'usdc after balance invalid');
    assert(usdc.balance_of(controller_addr) == 1000000, 'usdc of controller invalid');
    assert(controller.get_pool_balance(usdc_address) == 0, 'pool balance usdc invalid');

    assert(optiontoken.balance_of(account1) == 0, 'optiontoken balance invalid');
    assert(writertoken.balance_of(account1) == 0, 'writertoken balance invalid');
    assert(optiontoken.balance_of(controller.contract_address) == 0, 'optiontoken balance invalid');
    assert(writertoken.balance_of(controller.contract_address) == 0, 'writertoken balance invalid');
    assert(optiontoken.total_supply() == 0, 'optiontoken totalsupply invalid');
    assert(writertoken.total_supply() == 0, 'writertoken totalsupply invalid');
}
