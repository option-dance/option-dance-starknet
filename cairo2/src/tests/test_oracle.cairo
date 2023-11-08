use array::ArrayTrait;
use result::ResultTrait;
use serde::Serde;
use traits::Into;
use option::OptionTrait;
use traits::TryInto;

use debug::PrintTrait;
use starknet::{
    get_contract_address, get_caller_address, deploy_syscall, contract_address_to_felt252,
    contract_address_const
};
use starknet::testing::{
    set_block_timestamp, set_contract_address, set_account_contract_address, set_caller_address
};


use optiondance::oracle::{IOracleDispatcher, IOracleDispatcherTrait, Oracle};
use optiondance::pragma_pricer::{
    IPragmaPricerDispatcher, IPragmaPricerDispatcherTrait, PragmaPricer
};
use optiondance::mocks::mock_pragma_oracle::{
    IMockPragmaOracleDispatcher, IMockPragmaOracleDispatcherTrait, MockPragmaOracle
};

use optiondance::tests::test_controller::{deploy_mockerc20};
use optiondance::tests::test_utils::{account};


#[test]
#[available_gas(300000000)]
fn test_deploy_oracle() {
    let account1 = account(1);
    let account2 = account(2);
    let expiry_timestamp = 1671840000; // 2022-12-24T08:00

    let mut calldata: Array<felt252> = ArrayTrait::new();
    Serde::serialize(@account1, ref calldata);
    Serde::serialize(@account1, ref calldata);
    calldata.append(1800);

    let (address, _) = deploy_syscall(
        Oracle::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    let oracle = IOracleDispatcher { contract_address: address };

    assert(oracle.owner() == account1, 'wrong oracle owner');
    assert(oracle.is_price_syncer(account1) == true, 'wrong oracle pricer');
    assert(oracle.get_dispute_time() == 1800, 'wrong dispute_time');

    // test set price_syncer
    assert(oracle.is_price_syncer(account2) == false, 'account2 is not pricer');

    set_contract_address(account1);
    oracle.set_price_syncer(account2, true);
    assert(oracle.is_price_syncer(account2) == true, 'account2 is pricer');

    // test get expiry price when price not set by pricer
    set_block_timestamp(expiry_timestamp - 100);
    let mock_usdc = contract_address_const::<0x47a707C5D559CE163D1919b66AAdC2D00686f563>();
    let (price, enabled) = oracle.get_expiry_price(mock_usdc, expiry_timestamp);
    assert(price == 0, 'price == 0');
    assert(enabled == false, 'not enabled');

    // test set dispute_time
    oracle.set_dispute_time(900);
    assert(oracle.get_dispute_time() == 900, 'wrong dispute_time');

    // test set_expiry_price
    set_block_timestamp(expiry_timestamp + 1);
    oracle.set_expiry_price(mock_usdc, expiry_timestamp, 3000000000000);
    let (price, enabled) = oracle.get_expiry_price(mock_usdc, expiry_timestamp);
    assert(price == 3000000000000, 'price == 0');
    assert(enabled == false, 'not enabled');

    // test after dispute time, settle is enabled
    set_block_timestamp(expiry_timestamp + 901);
    let (price, enabled) = oracle.get_expiry_price(mock_usdc, expiry_timestamp);
    assert(price == 3000000000000, 'price == 0');
    assert(enabled == true, 'enabled');
}


#[test]
#[available_gas(300000000)]
fn test_oracle_with_mock_pragma_oracle() {
    let account1 = account(1);
    let account2 = account(2);
    let expiry_timestamp: u64 = 1671840000; // 2022-12-24T08:00

    let mut calldata: Array<felt252> = ArrayTrait::new();
    Serde::serialize(@account1, ref calldata);
    Serde::serialize(@account1, ref calldata);
    calldata.append(1800);

    //deploy optiondance oracle
    let (address, _) = deploy_syscall(
        Oracle::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();
    let oracle = IOracleDispatcher { contract_address: address };

    // deploy mock pragma oracle
    let (address, _) = deploy_syscall(
        MockPragmaOracle::TEST_CLASS_HASH.try_into().unwrap(), 0, ArrayTrait::new().span(), false
    )
        .unwrap();
    let mock_pragma_oracle = IMockPragmaOracleDispatcher { contract_address: address };

    // deploy pragma pricer, set owner to account1
    let mut calldata: Array<felt252> = ArrayTrait::new();
    Serde::serialize(@account1, ref calldata);
    Serde::serialize(@oracle.contract_address, ref calldata);
    Serde::serialize(@mock_pragma_oracle.contract_address, ref calldata);
    let (address, _) = deploy_syscall(
        PragmaPricer::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();
    let pragma_pricer = IPragmaPricerDispatcher { contract_address: address };

    let (wbtc, wbtc_address) = deploy_mockerc20('WBTC', 'WBTC', 8);
    let wbtc_pair_id = 18669995996566340;
    set_contract_address(account1);
    pragma_pricer.bind_asset_pair_id(wbtc_address, wbtc_pair_id);

    // test set price_syncer to pragma_pricer
    oracle.set_price_syncer(pragma_pricer.contract_address, true);
    assert(
        oracle.is_price_syncer(pragma_pricer.contract_address) == true, 'pragma_pricer is pricer'
    );

    // set mock pragma oracle
    mock_pragma_oracle.set_spot_median(wbtc_pair_id, 2980000000000, 8, expiry_timestamp.into(), 3);

    // test get price though pragma pricer
    set_block_timestamp(expiry_timestamp + 2);
    let (price, decimals, last_updated_timestamp, num_sources_aggregated, ) = pragma_pricer
        .get_spot_median(wbtc_pair_id);
    assert(price == 2980000000000, 'wrong price');
    assert(decimals == 8, 'wrong decimals');
    assert(last_updated_timestamp == expiry_timestamp.into(), 'wrong last_updated_timestamp');
    assert(num_sources_aggregated == 3, 'wrong num_sources_aggregated');

    // set set_expiry_price_in_oracle
    pragma_pricer.set_expiry_price_in_oracle(wbtc_address, expiry_timestamp);
    let (price, enabled) = oracle.get_expiry_price(wbtc_address, expiry_timestamp);
    assert(price == 2980000000000, 'wrong price');
    assert(enabled == false, 'wrong enable');
}
