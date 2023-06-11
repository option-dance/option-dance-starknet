%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.lib.Math64x61 import (
    Math64x61_add,
    Math64x61_fromUint256,
    Math64x61_mul,
    Math64x61_toFelt,
    Math64x61_div,
)
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_mul,
    uint256_le,
    uint256_lt,
    uint256_check,
    uint256_unsigned_div_rem,
)
from contracts.lib.time import timestamp_to_date

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return ();
}

@view
func get_date_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    expiry_timestamp: Uint256
) -> (res: felt) {
    let (ex) = Math64x61_fromUint256(expiry_timestamp);
    return (0,);
}

@view
func mul{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    a: Uint256, b: Uint256
) -> (res: felt) {
    let (aFelt) = Math64x61_fromUint256(a);
    let (bFelt) = Math64x61_fromUint256(b);

    let (ab, _) = uint256_mul(a, b);
    let (abFeltFixed) = Math64x61_mul(aFelt, bFelt);
    let (abFelt) = Math64x61_toFelt(abFeltFixed);
    return (0,);
}

@view
func div{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    a: Uint256, b: Uint256
) -> (res: felt) {
    alloc_locals;
    let (local aFelt) = Math64x61_fromUint256(a);
    let (bFelt) = Math64x61_fromUint256(b);

    let (local ab, _) = uint256_unsigned_div_rem(a, b);
    let (abFeltFixed) = Math64x61_div(aFelt, bFelt);
    let (abFelt) = Math64x61_toFelt(abFeltFixed);
    return (0,);
}

@view
func timestamp{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _timestamp: felt
) -> (year: felt, month: felt, day: felt) {
    alloc_locals;
    let (_year, _month, _day) = timestamp_to_date(_timestamp);
    return (_year, _month, _day);
}
