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

use optiondance::tests::test_controller::{deploy_mockerc20, expiry_timestamp};

const P: felt252 = 80;
const C: felt252 = 67;
const o: felt252 = 111;


fn setup() -> (IERC20Dispatcher, IERC20Dispatcher, IOracleDispatcher, IControllerDispatcher) {
    let owner = account(1);
    let account1 = account(1);
    let account2 = account(2);
    //deploy mock usdc and wbtc
    let (usdc, usdc_address) = deploy_mockerc20('USDC', 'USDC', 6);
    let (wbtc, wbtc_address) = deploy_mockerc20('WBTC', 'WBTC', 8);

    // deploy oracle contract, owner and disputor is account1
    let mut calldata: Array<felt252> = ArrayTrait::new();
    Serde::serialize(@account1, ref calldata);
    Serde::serialize(@account1, ref calldata);
    calldata.append(1800);
    let (address, _) = deploy_syscall(
        Oracle::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();
    let oracle = IOracleDispatcher { contract_address: address };

    // deploy controller contract
    let owner = account(1);
    set_caller_address(owner);
    let otoken_impl_class_hash: ClassHash = Otoken::TEST_CLASS_HASH.try_into().unwrap();

    let mut calldata = ArrayTrait::new();
    Serde::serialize(@owner, ref calldata);
    Serde::serialize(@otoken_impl_class_hash, ref calldata);
    Serde::serialize(@oracle.contract_address, ref calldata);
    let (controller_addr, _) = deploy_syscall(
        Controller::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();
    let controller = IControllerDispatcher { contract_address: controller_addr };
    (usdc, wbtc, oracle, controller)
}


fn setup_put_option() -> (
    IERC20Dispatcher,
    IERC20Dispatcher,
    IOtokenDispatcher,
    IOtokenDispatcher,
    IOracleDispatcher,
    IControllerDispatcher
) {
    let owner = account(1);
    let account1 = account(1);
    let account2 = account(2);
    let (usdc, wbtc, oracle, controller) = setup();
    // test create instrument
    set_contract_address(owner);
    controller.allow_underlying_asset(wbtc.contract_address, true);
    controller.allow_quote_asset(usdc.contract_address, true);
    let mut res = controller
        .create_instrument(
            wbtc.contract_address,
            usdc.contract_address,
            u256 { high: 0, low: 3000000000000 },
            expiry_timestamp.into(),
            80
        );
    let optiontoken = IOtokenDispatcher { contract_address: res.option_token };
    let writertoken = IOtokenDispatcher { contract_address: res.writer_token };

    // mint 30000 USDC to test account1
    usdc.mint(account1, 30000000000);
    // account1 call mintOption method, to send 30000 usdc to pool and mint 1 option
    set_contract_address(account1);
    usdc.approve(controller.contract_address, 30000000000);
    controller.mint_option(optiontoken.contract_address, 100000000);

    assert(usdc.balance_of(account1) == 0, 'usdc after balance invalid');
    assert(optiontoken.balance_of(account1) == 100000000, 'optiontoken balance invalid');
    assert(writertoken.balance_of(account1) == 3000000000000, 'writertoken balance invalid');
    assert(optiontoken.total_supply() == 100000000, 'optiontoken totalsupply invalid');
    assert(writertoken.total_supply() == 3000000000000, 'writertoken totalsupply invalid');

    //     # account1 send one option_token to account2 for sell one put option to account2 buyer
    set_contract_address(account1);
    optiontoken.transfer(account2, 100000000);

    (usdc, wbtc, optiontoken, writertoken, oracle, controller)
}


#[test]
#[available_gas(30000000)]
#[should_panic(expected: ('settle is not allowed', 'ENTRYPOINT_FAILED'))]
fn test_settle_before_expiry() {
    let (usdc, wbtc, optiontoken, writertoken, oracle, controller) = setup_put_option();
    // test: account1 settle before expiry should be reverted
    writertoken.approve(controller.contract_address, 30000000000);
    set_block_timestamp(expiry_timestamp - 100);
    controller.settle(writertoken.contract_address, 3000000000000);
}


#[test]
#[available_gas(30000000)]
#[should_panic(expected: ('cannot set price before expiry', 'ENTRYPOINT_FAILED'))]
fn test_oracle_set_price_before_expiry() {
    let (usdc, wbtc, optiontoken, writertoken, oracle, controller) = setup_put_option();
    set_block_timestamp(expiry_timestamp - 100);
    oracle.set_expiry_price(wbtc.contract_address, expiry_timestamp, 3800000000000);
}

#[test]
#[available_gas(30000000)]
#[should_panic(expected: ('no dispute after dispute time', 'ENTRYPOINT_FAILED'))]
fn test_oracle_dispute() {
    // price_syncer set btc expiry_price 2 times, first time is 38000
    let (usdc, wbtc, optiontoken, writertoken, oracle, controller) = setup_put_option();
    set_block_timestamp(expiry_timestamp);
    oracle.set_expiry_price(wbtc.contract_address, expiry_timestamp, 3800000000000);
    let (price, enabled) = oracle.get_expiry_price(wbtc.contract_address, expiry_timestamp);
    assert(price == 3800000000000, 'price == 0');
    assert(enabled == false, 'not enabled');
    //# second time is 40000
    // set_block_timestamp(expiry_timestamp + 1800);
    oracle.set_expiry_price(wbtc.contract_address, expiry_timestamp, 4000000000000);
    let (price, enabled) = oracle.get_expiry_price(wbtc.contract_address, expiry_timestamp);
    assert(price == 4000000000000, 'price == 0');
    assert(enabled == false, 'not enabled');
    // # after dispute time, price_syncer cannot set expiry price anymore
    set_block_timestamp(expiry_timestamp + 1800 + 1);
    oracle.set_expiry_price(wbtc.contract_address, expiry_timestamp, 4000000000000);
}


#[test]
#[available_gas(30000000)]
fn test_settle_and_exercise_put_otm() {
    let account1 = account(1);
    let account2 = account(2);
    let (usdc, wbtc, optiontoken, writertoken, oracle, controller) = setup_put_option();
    set_block_timestamp(expiry_timestamp);
    oracle.set_expiry_price(wbtc.contract_address, expiry_timestamp, 4000000000000);
    set_block_timestamp(expiry_timestamp + 1800 + 1);

    // settle
    controller.settle(writertoken.contract_address, 3000000000000);
    assert(usdc.balance_of(account1) == 30000000000, 'usdc after balance invalid');
    assert(usdc.balance_of(controller.contract_address) == 0, 'usdc after balance invalid');
    assert(writertoken.balance_of(account1) == 0, 'writertoken balance invalid');
    assert(writertoken.total_supply() == 0, 'writertoken totalsupply invalid');

    // exercise
    set_contract_address(account2);
    controller.exercise(optiontoken.contract_address, 100000000);
    assert(usdc.balance_of(account2) == 0, 'usdc after balance invalid');
    assert(usdc.balance_of(controller.contract_address) == 0, 'usdc after balance invalid');
    assert(optiontoken.balance_of(account2) == 0, 'optiontoken balance invalid');
    assert(optiontoken.total_supply() == 0, 'optiontoken totalsupply invalid');
}
