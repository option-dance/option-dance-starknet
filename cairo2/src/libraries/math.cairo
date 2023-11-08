use traits::Into;
use traits::TryInto;
use option::OptionTrait;
// u256 div mod function, return quotient and remainder
fn u256_div_rem(_value: u256, _div: u256) -> (u256, u256) {

    let value: u128 = _value.try_into().unwrap();
    let div: u128 = _div.try_into().unwrap();
    let quotient = value / div;
    let remainder = value % div;
    assert(quotient * div + remainder == value, 'div_rem error');
    (quotient.into(), remainder.into())
}


fn u128_div_rem(value: u128, div: u128) -> (u128, u128) {
    let quotient = value / div;
    let remainder = value % div;
    assert(quotient * div + remainder == value, 'div_rem error');
    (quotient.into(), remainder.into())
}


// fn u256_pow(base: u256, mut exp: usize) -> u256 {
//     let mut res = 1;
//     loop {
//         if exp == 0 {
//             break res;
//         } else {
//             res = base * res;
//         }
//         exp = exp - 1;
//     }
// }

// common u256 pow
fn u256_pow(base: u256, exponent: u32) -> u256 {
    if exponent == 0 {
        return 1;
    }
    
    let half_power = u256_pow(base, exponent / 2);
    
    if exponent % 2 == 0 {
        half_power * half_power
    } else {
        base * half_power * half_power
    }
}


fn flet252_pow(base: felt252, exponent: u8) -> felt252 {
    if exponent == 0 {
        return 1;
    }

    let half_power = flet252_pow(base, exponent / 2);
    
    if exponent % 2 == 0 {
        half_power * half_power
    } else {
        base * half_power * half_power
    }
}

fn u256_to_felt(u: u256) -> felt252 {
    let r: felt252 = u.try_into().unwrap();
    return r;
}



// a: atoken amount
// b: btoken amount
// a_decimals: atoken decimals
// b_decimals: btoken decimals
// eg. a is USDC(decimals = 6), b is WBTC(decimals = 8)
// 6USDC * 2WBTC = 12 => 6000000 * 200000000 = 12000000 expected
fn mul_with_decimals(a: u256, b:u256, a_decimals: u8, b_decimals: u8) -> u256 {
    let apow = flet252_pow(10, a_decimals);
    let bpow = flet252_pow(10, b_decimals);
    let abpow = flet252_pow(10, a_decimals + b_decimals);

    let x = a * bpow.into() * b * apow.into();
    let (r3, _) =    u256_div_rem(x, abpow.into());
    let (r4, _) = u256_div_rem(r3, bpow.into());
    return r4;
}

// a: atoken amount
// b: btoken amount
// a_decimals: atoken decimals
// b_decimals: btoken decimals
// eg. a is USDC(decimals = 6), b is WBTC(decimals = 8)
// 1USDC -> 1BTC => 1000000 -> 100000000  expected

fn convert_with_decimals(
    from_: u256, from_decimals: u8, to_decimals: u8
) -> u256 {
    let from_pow = flet252_pow(10, from_decimals);
    let to_pow = flet252_pow(10, to_decimals);
    
    let r0 = from_ * to_pow.into();
    let (r1,_) = u256_div_rem(r0, from_pow.into());
    return r1;
}
