%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from openzeppelin.access.ownable.library import Ownable
from contracts.types import ExpiryPrice, Instrument
from contracts.interfaces.IEmpiricOracle import IEmpiricOracle, EmpiricAggregationModes
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_lt, uint256_add
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_block_timestamp, get_caller_address
from starkware.cairo.common.math_cmp import is_le, is_not_zero
from starkware.cairo.common.math import assert_le

//
// Storage
//
@storage_var
func oracle_pricer(pricer: felt) -> (enabled: felt) {
}

@storage_var
func oracle_dispute_time() -> (res: felt) {
}

@storage_var
func oracle_expiry_price(asset: felt, expiry_timestamp: felt) -> (res: ExpiryPrice) {
}

//
// Events
//
@event
func oracle_pricer_updated(
    pricer: felt,
    enabled: felt
) {
}

@event
func oracle_dispute_time_updated(
    dispute_time: felt,
) {
}

@event
func oracle_expiry_price_updated(
    pricer: felt,
    asset: felt,
    expiry_timestamp: felt,
    expiry_price: ExpiryPrice
) {
}


@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _owner: felt, _pricer: felt, _dispute_time: felt
) {
    Ownable.initializer(_owner);
    oracle_pricer.write(_pricer, TRUE);
    oracle_dispute_time.write(_dispute_time);

    oracle_dispute_time_updated.emit(_dispute_time);
    oracle_pricer_updated.emit(_pricer, TRUE);
    return ();
}

//
// Getters
//
@view
func get_expiry_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    asset: felt, expiry_timestamp: felt
) -> (price: Uint256, settle_enabled: felt) {
    alloc_locals;
    let (block_timestamp) = get_block_timestamp();
    let (_expiry_price) = oracle_expiry_price.read(asset, expiry_timestamp);

    // check if price timestamp is valid
    let is_price_timestamp_valid = is_le(1, _expiry_price.timestamp);
    if (is_price_timestamp_valid == FALSE) {
        return (_expiry_price.price, FALSE);
    }
    //check if price is valid, should > 10 ^ 6 (0.01)
    let (is_price_invalid) = uint256_lt(_expiry_price.price, Uint256(1000000,0));
    if (is_price_invalid == TRUE) {
        return (_expiry_price.price, FALSE);
    }

    let (dispute_time) = get_dispute_time();
    let dispute_end_at = _expiry_price.timestamp + dispute_time;
    let is_in_dispute = is_le(block_timestamp, dispute_end_at);
    if (is_in_dispute == TRUE) {
        return (_expiry_price.price, FALSE);
    } else {
        return (_expiry_price.price, TRUE);
    }
}

@view
func owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
    let (owner) = Ownable.owner();
    return (owner,);
}

@view
func is_pricer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(pricer: felt) -> (
    enabled: felt
) {
    let (enabled) = oracle_pricer.read(pricer);
    return (enabled,);
}

@view
func get_dispute_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    dispute_time: felt
) {
    let (dispute_time) = oracle_dispute_time.read();
    return (dispute_time,);
}


//
// Setters
//
@external
func transferOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_owner: felt
) {
    Ownable.transfer_ownership(new_owner);
    return ();
}

@external
func set_dispute_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    dispute_time: felt
) {
    Ownable.assert_only_owner();
    oracle_dispute_time.write(dispute_time);
    oracle_dispute_time_updated.emit(dispute_time);
    return ();
}

@external
func set_pricer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _pricer: felt, _enabled: felt,
) {
    Ownable.assert_only_owner();
    let (enabled) = is_pricer(_pricer);
    if (enabled == TRUE) {
        with_attr error_message("cannot set same pricer status") {
            assert _enabled = FALSE;
        }    
    }else {
        with_attr error_message("cannot set same pricer status") {
            assert _enabled = TRUE;
        }    
    }
    oracle_pricer.write(_pricer, _enabled);
    oracle_pricer_updated.emit(_pricer, TRUE);
    return ();
}

@external
func set_expiry_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    asset: felt, expiry_timestamp: felt, expiry_price: Uint256
) {
    alloc_locals;
    assert_only_pricer();

    let (block_timestamp) = get_block_timestamp();
    with_attr error_message("cannot set price before expiry time") {
        assert_le(expiry_timestamp, block_timestamp);
    }
    let (caller) = get_caller_address();

    let (pre_expiry_price) = oracle_expiry_price.read(asset, expiry_timestamp);
    let (is_price_not_zero) = uint256_lt(Uint256(0, 0), pre_expiry_price.price);
    if (is_price_not_zero == TRUE) {
        // if expiryPrice is already set
        let (dispute_time) = get_dispute_time();
        let dispute_end_at = pre_expiry_price.timestamp + dispute_time;
        with_attr error_message("cannot dispute after dispute time") {
            assert_le(block_timestamp, dispute_end_at);
        }
        // update exists expiry price
        oracle_expiry_price.write(
            asset, expiry_timestamp, ExpiryPrice(expiry_price, pre_expiry_price.timestamp)
        );
        oracle_expiry_price_updated.emit(caller, asset, expiry_timestamp, ExpiryPrice(expiry_price, pre_expiry_price.timestamp));
        return ();
    } else {
        // if expiryPrice is not set
        oracle_expiry_price.write(
            asset, expiry_timestamp, ExpiryPrice(expiry_price, block_timestamp)
        );
        oracle_expiry_price_updated.emit(caller, asset, expiry_timestamp, ExpiryPrice(expiry_price, block_timestamp));
        return ();
    }
}

func assert_only_pricer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (caller) = get_caller_address();
    let (enabled) = is_pricer(caller);
    with_attr error_message("caller is not pricer") {
        assert enabled = TRUE;
    }
    return ();
}