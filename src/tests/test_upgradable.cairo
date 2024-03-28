use traits::Into;
use traits::TryInto;
use option::OptionTrait;
use array::ArrayTrait;
use result::ResultTrait;


use optiondance::libraries::erc20::{IERC20Dispatcher, IERC20DispatcherTrait, ERC20};

use optiondance::mocks::mock_proxy_ctrl_v1::{IControllerV1Dispatcher,IControllerV1DispatcherTrait, ControllerV1  };
use optiondance::mocks::mock_proxy_ctrl_v2::{IControllerV2Dispatcher,IControllerV2DispatcherTrait, ControllerV2  };
use optiondance::tests::test_utils::{account};
use starknet::{get_contract_address, get_caller_address, deploy_syscall, ClassHash, contract_address_const,
ContractAddress, contract_address_to_felt252,
testing::{set_block_timestamp, set_contract_address, set_account_contract_address, set_caller_address}};
use optiondance::tests::test_controller::{deploy_mockerc20};

#[test]
#[available_gas(3000000)]
fn test_upgradable() {

    // set caller address
    let owner = account(1);
    set_contract_address(owner);


    //deploy a ERC20 token
    let (usdc, usdc_address) = deploy_mockerc20('USDC', 'USDC', 6);

    // deploy v1 controller
    let oracle_address = contract_address_const::<123>();
    let mut calldata = ArrayTrait::new();
    Serde::serialize(@oracle_address, ref calldata);
    let (controller_addr, _) = deploy_syscall(ControllerV1::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false).unwrap();
    let mut controller =  IControllerV1Dispatcher { contract_address: controller_addr  };

    // mint 100 usdc to v1 controller
    usdc.mint(controller.contract_address, 100000000);
    assert(usdc.balance_of(controller.contract_address) == 100000000, 'usdc balance invalid');

    assert(controller.get_oracle() == oracle_address, 'wrong oracle');

    // upgrade to v2
    let controller_v2_classhash = ControllerV2::TEST_CLASS_HASH.try_into().unwrap();
    set_contract_address(owner);
    controller.upgrade(controller_v2_classhash);
    // assign controller to v2
    let controller =  IControllerV2Dispatcher { contract_address: controller_addr  };

    // mint 100 usdc to v2 controller
    usdc.mint(controller.contract_address, 100000000);
    assert(usdc.balance_of(controller.contract_address) == 200000000, 'usdc balance invalid');

    //test v2 methods
    assert(controller.get_oracle_v2() == oracle_address, 'wrong oracle');

}
