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

use optiondance::tests::test_expired_put_otm::{setup};
use optiondance::tests::test_controller::{deploy_mockerc20, expiry_timestamp};

const P: felt252 = 80;
const C: felt252 = 67;


fn setup_call_option() -> (
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
            wbtc.contract_address,
            u256 { high: 0, low: 3000000000000 },
            expiry_timestamp.into(),
            67
        );
    let optiontoken = IOtokenDispatcher { contract_address: res.option_token };
    let writertoken = IOtokenDispatcher { contract_address: res.writer_token };

    // mint 1 WBTC to test account1
    wbtc.mint(account1, 100000000);
    // account1 call mintOption method, to send 1 wbtc to pool and mint 1 option
    set_contract_address(account1);
    wbtc.approve(controller.contract_address, 100000000);
    controller.mint_option(optiontoken.contract_address, 100000000);

    assert(wbtc.balance_of(account1) == 0, 'usdc after balance invalid');
    assert(optiontoken.balance_of(account1) == 100000000, 'optiontoken balance invalid');
    assert(writertoken.balance_of(account1) == 100000000, 'writertoken balance invalid');
    assert(optiontoken.total_supply() == 100000000, 'optiontoken totalsupply invalid');
    assert(writertoken.total_supply() == 100000000, 'writertoken totalsupply invalid');

    // account1 send one option_token to account2 for sell one call option to account2 buyer
    set_contract_address(account1);
    optiontoken.transfer(account2, 100000000);

    (usdc, wbtc, optiontoken, writertoken, oracle, controller)
}


#[test]
#[available_gas(30000000)]
fn test_settle_and_exercise_call_otm() {
    let account1 = account(1);
    let account2 = account(2);
    let (usdc, wbtc, optiontoken, writertoken, oracle, controller) = setup_call_option();
    set_block_timestamp(expiry_timestamp);
    oracle.set_expiry_price(wbtc.contract_address, expiry_timestamp, 2000000000000);
    set_block_timestamp(expiry_timestamp + 1800 + 1);

    // settle
    controller.settle(writertoken.contract_address, 100000000);
    assert(wbtc.balance_of(account1) == 100000000, 'btc after balance invalid');
    assert(wbtc.balance_of(controller.contract_address) == 0, 'wbtc after balance invalid');
    assert(writertoken.balance_of(account1) == 0, 'writertoken balance invalid');
    assert(writertoken.total_supply() == 0, 'writertoken totalsupply invalid');

    // exercise
    set_contract_address(account2);
    controller.exercise(optiontoken.contract_address, 100000000);
    assert(wbtc.balance_of(account2) == 0, 'wbtc after balance invalid');
    assert(wbtc.balance_of(controller.contract_address) == 0, 'wbtc after balance invalid');
    assert(optiontoken.balance_of(account2) == 0, 'optiontoken balance invalid');
    assert(optiontoken.total_supply() == 0, 'optiontoken totalsupply invalid');
}
