// builtins.
%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.hash_state import (
    HashState,
    hash_finalize,
    hash_init,
    hash_update,
    hash_update_single,
    hash2,
)
from starkware.cairo.common.math import assert_nn_le, assert_not_zero, assert_nn, assert_lt
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.bool import TRUE, FALSE
from openzeppelin.token.erc20.IERC20 import IERC20
// from openzeppelin.account.IAccount import IAccount
from openzeppelin.account.library import AccountCallArray
//
// Message Config
//

const STARKNET_MESSAGE_PREFIX = 'StarkNet Message';
const DOMAIN_NAME = 'Option Dance';
const CHAIN_ID = 'goerli-alpha';
const APP_VERSION = 1;
const STARKNET_DOMAIN_TYPE_HASH = 0x98d1932052fc5137543de5ed85b7a88555a4cd1ff5d5bfedb62ed9b9a1f0db;
const ORDER_TYPE_HASH = 0x1b801a20e1f41f77266c93f25e6d9cae5262181bc6d4aec248866fb2a71bfbc;
const PRICE_TYPE_HASH = 0x1fe7f2a33d0248cd65cc2817d17660a0a4d2978dcedc06d0493258eb7f2ef46;

//
// Order Config
//
const BUY_SIDE = 0;
const SELL_SIDE = 1;


@contract_interface
namespace IAccount {

    func supportsInterface(interfaceId: felt) -> (success: felt) {
    }

    func is_valid_signature(hash: felt, signature_len: felt, signature: felt*) -> (isValid: felt) {
    }

    func __validate__(
        call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*
    ) {
    }

    func __validate_declare__(cls_hash: felt) {
    }

    func __execute__(
        call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*
    ) -> (response_len: felt, response: felt*) {
    }
}



//#############
// Structs
//#############

struct StarkNet_Domain {
    name: felt,
    version: felt,
    chain_id: felt,
}

struct PriceRatio {
    numerator: felt,
    denominator: felt,
}

struct Order {
    base_asset: felt,
    quote_asset: felt,
    side: felt,  // 0 = buy, 1 = sell
    base_quantity: felt,
    price: PriceRatio,
    expiration: felt,
    salt: felt,
}

struct Message {
    message_prefix: felt,
    domain_prefix: StarkNet_Domain,
    sender: felt,
    order: Order,
    sig_r: felt,
    sig_s: felt,
}

//#############
// Verification
//#############


// sanity checks for valid order
func check_order_valid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    buy_order: Order*,
    sell_order: Order*,
    filledbuy: felt,
    filledsell: felt,
    base_fill_quantity: felt,
    fill_price: PriceRatio,
) -> (bool: felt) {
    alloc_locals;

    // Needed for dereferencing buy_order and sell_order
    let fp_and_pc = get_fp_and_pc();
    tempvar __fp__ = fp_and_pc.fp_val;

    // Run order checks
    with_attr error_message("Invalid order") {
        assert buy_order.base_asset = sell_order.base_asset;
        assert buy_order.quote_asset = sell_order.quote_asset;
        assert buy_order.side = BUY_SIDE;
        assert sell_order.side = SELL_SIDE;
        assert_nn_le(0, filledbuy);  // Sanity Check
        assert_nn_le(0, filledsell);  // Sanity Check
        assert_nn_le(0, buy_order.base_quantity);
        assert_nn_le(0, sell_order.base_quantity);
        assert_nn_le(0, base_fill_quantity);
        assert_nn_le(filledbuy + base_fill_quantity, buy_order.base_quantity);
        assert_nn_le(filledsell + base_fill_quantity, sell_order.base_quantity);
        assert_nn_le(
            fill_price.numerator * buy_order.price.denominator,
            buy_order.price.numerator * fill_price.denominator,
        );
        assert_nn_le(
            sell_order.price.numerator * fill_price.denominator,
            fill_price.numerator * sell_order.price.denominator,
        );
        assert_nn_le(base_fill_quantity, buy_order.base_quantity);
        assert_nn_le(base_fill_quantity, sell_order.base_quantity);

        let (contract_time: felt) = get_block_timestamp();

        assert_nn_le(contract_time, buy_order.expiration);
        assert_nn_le(contract_time, sell_order.expiration);
    }
    return (TRUE,);
}

// validate_message
func validate_message_prefix{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    msg_ptr: Message*
) -> (bool: felt) {
    alloc_locals;

    // Needed for dereferencing buy_order and sell_order
    let fp_and_pc = get_fp_and_pc();
    tempvar __fp__ = fp_and_pc.fp_val;

    // Run message checks
    with_attr error_message("Invalid Message") {
        assert msg_ptr.message_prefix = STARKNET_MESSAGE_PREFIX;
        assert msg_ptr.domain_prefix.name = DOMAIN_NAME;
        assert msg_ptr.domain_prefix.version = APP_VERSION;
        assert msg_ptr.domain_prefix.chain_id = CHAIN_ID;
    }
    return (TRUE,);
}

// Verifies an order signature
func verify_message_signature{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    msg_ptr: Message*
) -> (bool: felt) {
    alloc_locals;
    let (local msghash: felt) = compute_message_hash(msg_ptr);

    IAccount.is_valid_signature(
        contract_address=msg_ptr.sender, hash=msghash, signature_len=2, signature=&msg_ptr.sig_r
    );
    return (TRUE,);
}

// hash structs methods, see https://github.com/argentlabs/argent-contracts-starknet/blob/develop/contracts/test/StructHash.cairo 
// takes StarkNetDomain and returns its struct_hash
func hash_domain{hash_ptr: HashBuiltin*}(domain: StarkNet_Domain*) -> (hash: felt) {
    let (hash_state: HashState*) = hash_init();
    let (hash_state) = hash_update_single(
        hash_state_ptr=hash_state, item=STARKNET_DOMAIN_TYPE_HASH
    );
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=domain.name);
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=domain.chain_id);
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=domain.version);
    let (hash: felt) = hash_finalize(hash_state_ptr=hash_state);
    return (hash=hash);
}


// takes PriceRatio and returns its struct_hash
func hash_price_ratio{hash_ptr: HashBuiltin*}(priceRatio: PriceRatio*) -> (hash: felt) {
    let (hash_state: HashState*) = hash_init();
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=PRICE_TYPE_HASH);
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=priceRatio.numerator);
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=priceRatio.denominator);
    let (hash: felt) = hash_finalize(hash_state_ptr=hash_state);
    return (hash=hash);
}

// takes Order and returns its struct_hash
func hash_order{hash_ptr: HashBuiltin*}(order: Order*) -> (hash: felt) {
    let (hash_state: HashState*) = hash_init();
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=ORDER_TYPE_HASH);
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=order.base_asset);
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=order.quote_asset);
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=order.side);
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=order.base_quantity);
    let (priceRatioHash: felt) = hash_price_ratio(&order.price);
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=priceRatioHash);
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=order.expiration);
    let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=order.salt);
    let (hash: felt) = hash_finalize(hash_state_ptr=hash_state);
    return (hash=hash);
}


// takes Message and returns its struct_hash
func compute_message_hash{pedersen_ptr: HashBuiltin*, range_check_ptr}(msg: Message*) -> (hash: felt) {
    let hash_ptr = pedersen_ptr;
    with hash_ptr {
        let (hash_state: HashState*) = hash_init();
        // message_prefix hash
        let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=msg.message_prefix);
        // domain hash
        let (domainHash: felt) = hash_domain(&msg.domain_prefix);
        let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=domainHash);
        // sender hash
        let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=msg.sender);
        // orderhash
        let (orderHash: felt) = hash_order(&msg.order);
        let (hash_state) = hash_update_single(hash_state_ptr=hash_state, item=orderHash);
        let (hash: felt) = hash_finalize(hash_state_ptr=hash_state);
        let pedersen_ptr = hash_ptr;
        return (hash=hash);
    }
}
//#############
// CONSTRUCTOR
//#############

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return ();
}

//#############
// STORAGE
//#############

// Storage variable for order tracking
@storage_var
func orderstatus(messagehash: felt) -> (filled: felt) {
}

func execute_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_fill_quantity: felt,
    fill_price: PriceRatio,
    base_asset: felt,
    quote_asset: felt,
    buyer: felt,
    seller: felt,
) -> (bool: felt) {
    alloc_locals;

    let fp_and_pc = get_fp_and_pc();
    tempvar __fp__ = fp_and_pc.fp_val;

    // Transfer tokens
    let (quote_fill_quantity, remainder_fill_qty) = unsigned_div_rem(
        base_fill_quantity * fill_price.numerator, fill_price.denominator
    );
    IERC20.transferFrom(
        contract_address=base_asset,
        sender=seller,
        recipient=buyer,
        amount=Uint256(base_fill_quantity, 0),
    );
    IERC20.transferFrom(
        contract_address=quote_asset,
        sender=buyer,
        recipient=seller,
        amount=Uint256(quote_fill_quantity, 0),
    );

    return (TRUE,);
}

@external
func fill_order{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*, range_check_ptr
}(buy_order: Message, sell_order: Message, fill_price: PriceRatio, base_fill_quantity: felt) {
    alloc_locals;

    // Needed for dereferencing buy_order and sell_order
    let fp_and_pc = get_fp_and_pc();
    tempvar __fp__ = fp_and_pc.fp_val;

    // validate message prefixes
    let (local check_buy: felt) = validate_message_prefix(&buy_order);
    let (local check_sell: felt) = validate_message_prefix(&sell_order);

    assert check_buy = TRUE;
    assert check_sell = TRUE;

    // validate order
    let (local buymessagehash: felt) = compute_message_hash(&buy_order);
    let (local sellmessagehash: felt) = compute_message_hash(&sell_order);
    let (local filledbuy: felt) = orderstatus.read(buymessagehash);
    let (local filledsell: felt) = orderstatus.read(sellmessagehash);

    let (local check_order: felt) = check_order_valid(
        &buy_order.order, &sell_order.order, filledbuy, filledsell, base_fill_quantity, fill_price
    );

    assert check_order = TRUE;

    // Check sigs
    let (local check_buy_sig: felt) = verify_message_signature(&buy_order);
    let (local check_sell_sig: felt) = verify_message_signature(&sell_order);

    assert check_buy_sig = TRUE;
    assert check_sell_sig = TRUE;

    // execute trade
    let (local fulfilled: felt) = execute_trade(
        base_fill_quantity,
        fill_price,
        buy_order.order.base_asset,
        buy_order.order.quote_asset,
        buy_order.sender,
        sell_order.sender,
    );

    assert fulfilled = TRUE;

    orderstatus.write(buymessagehash, filledbuy + base_fill_quantity);
    orderstatus.write(sellmessagehash, filledsell + base_fill_quantity);
    return ();
}

// Cancels an order by setting the fill quantity to greater than the order size
@external
func cancel_order{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*, range_check_ptr
}(order: Message) {
    alloc_locals;

    // Needed for dereferencing order
    let fp_and_pc = get_fp_and_pc();
    tempvar __fp__ = fp_and_pc.fp_val;

    let (caller) = get_caller_address();
    assert caller = order.sender;
    let (orderhash) = compute_message_hash(&order);
    orderstatus.write(orderhash, order.order.base_quantity + 1);
    return ();
}

// Returns an order status
@view
func get_order_status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    orderhash: felt
) -> (filled: felt) {
    let (filled) = orderstatus.read(orderhash);
    return (filled,);
}
