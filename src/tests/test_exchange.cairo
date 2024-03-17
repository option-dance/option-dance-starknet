use array::{ArrayTrait, SpanTrait};
use traits::Into;
use traits::TryInto;
use option::OptionTrait;
use result::ResultTrait;
use optiondance::libraries::hash::{compute_hash_on_elements};
use optiondance::tests::test_utils::{account};
use optiondance::tests::test_controller::{deploy_mockerc20};

use optiondance::exchange::{IExchangeDispatcher, IExchangeDispatcherTrait, Exchange, 
 StarkNetDomain, PriceRatio, Order, Message   };

use optiondance::libraries::erc20::{IERC20Dispatcher, IERC20DispatcherTrait, ERC20};
use starknet::{get_contract_address, get_caller_address, deploy_syscall, ClassHash, contract_address_const,
ContractAddress, contract_address_to_felt252,
testing::{set_block_timestamp, set_contract_address, set_account_contract_address, set_caller_address}};

#[test]
#[available_gas(300000000)]
fn test_compute_hash_on_elements() {  
    let  mut data :Array<felt252>  = ArrayTrait::new();
    data.append(1);
    data.append(2);
    let hash = compute_hash_on_elements(data);
    assert(hash == 0x501a3a8e6cd4f5241c639c74052aaa34557aafa84dd4ba983d6443c590ab7df, hash);

    let  mut data :Array<felt252>  = ArrayTrait::new();
    data.append(0x98d1932052fc5137543de5ed85b7a88555a4cd1ff5d5bfedb62ed9b9a1f0db);
    data.append('Option Dance');
    data.append('goerli-alpha');
    data.append(1);
    let hash = compute_hash_on_elements(data);
    assert(hash == 0x654ef9514f0e63c759848928c844c7a15dec4cc3cf9ffc72c16a8493f005d99, hash);
}



// #[test]
// #[available_gas(300000000)]
fn test_fill_order() {
    // get test account
    let account1 = account(1);
    let account2 = account(2);

    //deploy mock usdc and wbtc
    let (usdc, usdc_address) = deploy_mockerc20('USDC', 'USDC', 6);
    let (wbtc, wbtc_address) = deploy_mockerc20('WBTC', 'WBTC', 8);

    // delpoy exchange
    let owner = account(1);
    set_caller_address(owner);
    let mut calldata: Array<felt252> = ArrayTrait::new();
    let (exchange_addr, _) = deploy_syscall(Exchange::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false).unwrap();
    let exchange =  IExchangeDispatcher { contract_address: exchange_addr  };


    // mint tokens and approve
    wbtc.mint(account1, 100000000000000000000); // 1e20
    usdc.mint(account2, 100000000000000000000); // 1e20
    assert(wbtc.balance_of(account1) == 100000000000000000000, 'wbtc balance invalid');
    assert(wbtc.balance_of(account2) == 0, 'wbtc balance invalid');
    assert(usdc.balance_of(account1) == 0, 'usdc balance invalid');
    assert(usdc.balance_of(account2) == 100000000000000000000, 'usdc balance invalid');
    let approve_amount = 10000000000000000000000000;
    set_contract_address(account1);
    wbtc.approve(exchange.contract_address, approve_amount);
    set_contract_address(account2);
    usdc.approve(exchange.contract_address, approve_amount);

    assert(wbtc.allowance(account1, exchange.contract_address) == approve_amount, 'wbtc allowance invalid');
    assert(usdc.allowance(account2, exchange.contract_address) == approve_amount, 'usdc allowance invalid');


    // fill order
    let message_prefix = 'StarkNet Message';
    let domain_prefix: StarkNetDomain = StarkNetDomain{
        name: 'Option Dance',
        version: 1,
        chain_id: 'goerli-alpha' 
    };
    let buyer = contract_address_const::<0x0176107b5fd4e783ce0d42797a2dc83f01741a912830bcf1e2a45175c41439e3>();
    let seller = contract_address_const::<0x017dc6c4e55b66de2f9c6f7cf9d67954167e3abe8ec9e51300bf7e16ba841b7e>();

    let buy_message = Message {
        message_prefix: 'StarkNet Message',
        domain_prefix: domain_prefix,
        sender: contract_address_const::<0x0176107b5fd4e783ce0d42797a2dc83f01741a912830bcf1e2a45175c41439e3>(),
        order: Order {
            base_asset: wbtc_address,
            quote_asset: usdc_address,
            side: 0,  // 0 = buy, 1 = sell
            base_quantity: 100000000,
            price: PriceRatio{
                numerator: 1,
                denominator:100,
            },
            expiration: 168855412658,
            salt: '1935764596',
        },
        sig_r: 954364477230514063484975900357145151283396355133631761209462807057307923694,
        sig_s: 2800196834805050976467571133396791300999366572875102110568128099953555959190,
    };

    let sell_message = Message {
        message_prefix: 'StarkNet Message',
        domain_prefix: domain_prefix,
        sender: contract_address_const::<0x0176107b5fd4e783ce0d42797a2dc83f01741a912830bcf1e2a45175c41439e3>(),
        order: Order {
            base_asset: wbtc_address,
            quote_asset: usdc_address,
            side: 1,  // 0 = buy, 1 = sell
            base_quantity: 100000000,
            price: PriceRatio{
                numerator: 1,
                denominator:100,
            },
            expiration: 168855472235,
            salt: '1935764596',
        },
        sig_r: 2925106185686270929116024995095575664503442198054204844383280609554628282667,
        sig_s: 1265176989333031170040805643397063034861775329395581700408311708254268653146,
    };    

    let mut calldata: Array<felt252> = ArrayTrait::new();
    let fill_price : PriceRatio  = PriceRatio  {
                numerator: 1,
                denominator:100,
            };
            let base_fill_quantity = 100000000;
    Serde::serialize(@buy_message, ref calldata);
    Serde::serialize(@sell_message, ref calldata);
    Serde::serialize(@fill_price, ref calldata);
    Serde::serialize(@base_fill_quantity, ref calldata);
    let ret = exchange.fill_order(buy_message, sell_message, fill_price, base_fill_quantity);
    // assert(ret == base_fill_quantity, 'base_fill_quantity invalid');




}