use traits::Into;
use traits::TryInto;
use option::OptionTrait;
use array::ArrayTrait;
use result::ResultTrait;



use optiondance::mocks::mock_erc20::{IERC20Dispatcher, IERC20DispatcherTrait, ERC20};
use optiondance::tests::test_utils::{account};
use starknet::{get_contract_address, get_caller_address, deploy_syscall, ClassHash, contract_address_const,
ContractAddress, contract_address_to_felt252,
testing::{set_block_timestamp, set_contract_address, set_account_contract_address, set_caller_address}};
use optiondance::tests::test_controller::{deploy_mockerc20};


fn deploy_mock_erc20(
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


#[test]
#[available_gas(3000000)]
fn test_mock_erc20() {

    // set caller address
    let owner = account(1);
    set_caller_address(owner);


    //deploy a ERC20 token
    let (usdc, usdc_address) = deploy_mock_erc20('USDC', 'USDC', 6);

    // mint 100 usdc to v1 controller
    usdc.mint(owner, 100000000);
    assert(usdc.balance_of(owner) == 100000000, 'usdc balance invalid');
    assert(usdc.balanceOf(owner) == 100000000, 'usdc balance invalid');
    assert(usdc.total_supply() == 100000000, 'usdc balance invalid');
    assert(usdc.totalSupply() == 100000000, 'usdc balance invalid');
}