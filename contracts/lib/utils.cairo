%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import split_felt, assert_le_felt
from starkware.cairo.common.uint256 import Uint256
from contracts.lib.string import felt_to_string

const MAX_UINT128 = 2 ** 128 - 1;

func felt_to_uint256{range_check_ptr}(value: felt) -> (res: Uint256) {
    let (high: felt, low: felt) = split_felt(value);
    return (res=Uint256(low=low, high=high));
}

func uint256_to_felt{range_check_ptr}(amount: Uint256) -> (res: felt) {
    alloc_locals;
    let res = amount.low;
    with_attr error_message("amount exceed uint128 max value") {
        assert_le_felt(res, MAX_UINT128);
    }
    return (res,);
}

func uint256_to_felt_str{range_check_ptr}(amount: Uint256) -> (res: felt) {
    let (a) = uint256_to_felt(amount);
    let (r) = felt_to_string(a);
    return (res=r);
}
