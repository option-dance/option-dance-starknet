%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from openzeppelin.security.safemath.library import SafeUint256
from starkware.cairo.common.pow import pow

// a: atoken amount
// b: btoken amount
// a_decimals: atoken decimals
// b_decimals: btoken decimals
// eg. a is USDC(decimals = 6), b is WBTC(decimals = 8)
// 6USDC * 2WBTC = 12 => 6000000 * 200000000 = 12000000 expected
func mul_with_decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    a: Uint256, b: Uint256, a_decimals: felt, b_decimals: felt
) -> (res: Uint256) {
    alloc_locals;
    let (apow) = pow(10, a_decimals);
    let (bpow) = pow(10, b_decimals);
    let (abpow) = pow(10, a_decimals + b_decimals);

    let (r0) = SafeUint256.mul(a, Uint256(bpow, 0));
    let (r1) = SafeUint256.mul(r0, b);
    let (r2) = SafeUint256.mul(r1, Uint256(apow, 0));

    let (r3, _) = SafeUint256.div_rem(r2, Uint256(abpow, 0));
    let (r4, _) = SafeUint256.div_rem(r3, Uint256(bpow, 0));
    return (r4,);
}

// a: atoken amount
// b: btoken amount
// a_decimals: atoken decimals
// b_decimals: btoken decimals
// eg. a is USDC(decimals = 6), b is WBTC(decimals = 8)
// 1USDC -> 1BTC => 1000000 -> 100000000  expected
func convert_with_decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_: Uint256, from_decimals: felt, to_decimals: felt
) -> (res: Uint256) {
    alloc_locals;
    let (from_pow) = pow(10, from_decimals);
    let (to_pow) = pow(10, to_decimals);

    let (r0) = SafeUint256.mul(from_, Uint256(to_pow, 0));
    let (r1, _) = SafeUint256.div_rem(r0, Uint256(from_pow, 0));
    return (r1,);
}
