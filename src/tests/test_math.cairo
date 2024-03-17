use optiondance::libraries::math::{u256_pow,
 u256_div_rem, mul_with_decimals, convert_with_decimals};
 use optiondance::libraries::string::{felt_to_string, unsafe_literal_concat};
use debug::PrintTrait;

#[test]
#[available_gas(3000000)]
fn test_u256_div_rem() {
    let (q, r) = u256_div_rem(10, 3);
    assert(q == 3, 'q Should return 3');
    assert(r == 1, 'r Should return 1');
}



#[test]
#[available_gas(3000000)]
fn test_u256_pow() {
    assert(u256_pow(256, 2) == 65536, 'Should return 65536');
}


#[test]
#[available_gas(3000000)]
fn test_mul_with_decimals() {
    let ret = mul_with_decimals(6000000, 200000000, 6, 8);
    assert(ret == 12000000, 'Should return 12000000');
}



#[test]
#[available_gas(3000000)]
fn test_convert_with_decimals() {
    let ret = convert_with_decimals(1000000, 6, 8);
    assert(ret == 100000000, 'Should return 100000000');
    let strike = u256 {high: 0, low: 3000000000000};
    let ret = convert_with_decimals(strike, 8, 0);
    assert(ret == 30000, 'Should return 30000');
    let strike_price_felt = felt_to_string(ret);
}