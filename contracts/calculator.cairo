%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.types import Instrument
from contracts.lib.constant import OPTION_TYPE_CALL, OPTION_TYPE_PUT, OTOKEN_DECIMALS
from contracts.lib.uint256 import mul_with_decimals, convert_with_decimals
from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.token.erc20.IERC20 import IERC20
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_le,
    uint256_lt,
    uint256_add,
    uint256_mul,
    uint256_unsigned_div_rem,
    uint256_sub,
)
from starkware.cairo.common.bool import TRUE, FALSE

func get_fully_collateralized_margin{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(option_amount: Uint256, instrument: Instrument) -> (
    collateral_asset: felt, collateral_amount: Uint256
) {
    alloc_locals;
    let (local quote_asset_decimals) = IERC20.decimals(instrument.quote_asset);
    let (local underlying_asset_decimals) = IERC20.decimals(instrument.underlying_asset);

    if (OPTION_TYPE_PUT == instrument.option_type) {
        let (strike_price_integer) = convert_with_decimals(instrument.strike_price, 8, 0);
        let (quote_amount0) = SafeUint256.mul(option_amount, strike_price_integer);
        let (quote_amount1) = convert_with_decimals(
            quote_amount0, OTOKEN_DECIMALS, quote_asset_decimals
        );
        return (instrument.quote_asset, quote_amount1);
    } else {
        let (underlying_amount) = convert_with_decimals(
            option_amount, OTOKEN_DECIMALS, underlying_asset_decimals
        );
        return (instrument.underlying_asset, underlying_amount);
    }
}

func get_writer_token_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token_amount: Uint256, instrument: Instrument
) -> (writer_token_amount: Uint256) {
    alloc_locals;
    if (OPTION_TYPE_PUT == instrument.option_type) {
        let (strike_price_integer) = convert_with_decimals(instrument.strike_price, 8, 0);
        let (writer_token_amount) = SafeUint256.mul(option_token_amount, strike_price_integer);
        return (writer_token_amount,);
    } else {
        return (option_token_amount,);
    }
}

func get_expired_cash_value{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    writer_token_amount: Uint256, instrument: Instrument, expiry_price: Uint256
) -> (collateral_asset: felt, collateral_amount: Uint256, exercised: felt) {
    alloc_locals;
    let (local quote_asset_decimals) = IERC20.decimals(instrument.quote_asset);
    let (local underlying_asset_decimals) = IERC20.decimals(instrument.underlying_asset);

    if (OPTION_TYPE_PUT == instrument.option_type) {
        let (is_exercised) = uint256_lt(expiry_price, instrument.strike_price);
        if (is_exercised == TRUE) {
            // put option exercised: collateral amount can withdraw = (writer_token_amount * expiry_price) / instrument.strike_price)
            let (r1) = SafeUint256.mul(writer_token_amount, expiry_price);
            let (r2, _) = SafeUint256.div_rem(r1, instrument.strike_price);
            let (r3) = convert_with_decimals(r2, OTOKEN_DECIMALS, quote_asset_decimals);
            return (instrument.quote_asset, r3, TRUE);
        } else {
            // put option not exercised: collateral amount can withdraw = writer_token_amount
            let (r1) = convert_with_decimals(
                writer_token_amount, OTOKEN_DECIMALS, quote_asset_decimals
            );
            return (instrument.quote_asset, r1, FALSE);
        }
    } else {
        let (is_exercised) = uint256_lt(instrument.strike_price, expiry_price);
        if (is_exercised == TRUE) {
            // call option exercised: collateral amount can withdraw = (writer_token_amount * instrument.strike_price) / expiry_price)
            let (r1) = SafeUint256.mul(writer_token_amount, instrument.strike_price);
            let (r2, _) = SafeUint256.div_rem(r1, expiry_price);
            let (r3) = convert_with_decimals(r2, OTOKEN_DECIMALS, underlying_asset_decimals);
            return (instrument.underlying_asset, r3, TRUE);
        } else {
            // call option not exercised: collateral amount can withdraw = writer_token_amount
            let (r1) = convert_with_decimals(
                writer_token_amount, OTOKEN_DECIMALS, underlying_asset_decimals
            );
            return (instrument.underlying_asset, r1, FALSE);
        }
    }
}

func get_expired_otoken_profit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token_amount: Uint256, instrument: Instrument, expiry_price: Uint256
) -> (profit_asset: felt, profit_amount: Uint256, exercised: felt) {
    alloc_locals;
    let (local quote_asset_decimals) = IERC20.decimals(instrument.quote_asset);
    let (local underlying_asset_decimals) = IERC20.decimals(instrument.underlying_asset);

    if (OPTION_TYPE_PUT == instrument.option_type) {
        let (is_exercised) = uint256_lt(expiry_price, instrument.strike_price);
        if (is_exercised == TRUE) {
            // put option exercised: otoken profit amount = ( option_token_amount * ( instrument.strike_price - expiry_price))
            let (r1) = SafeUint256.sub_le(instrument.strike_price, expiry_price);
            let (r2) = SafeUint256.mul(r1, option_token_amount);
            let (r3) = convert_with_decimals(r2, 8, 0);
            let (r4) = convert_with_decimals(r3, OTOKEN_DECIMALS, quote_asset_decimals);
            return (instrument.quote_asset, r4, TRUE);
        } else {
            // put option not exercised: otoken profit amount = 0
            return (instrument.quote_asset, Uint256(0, 0), FALSE);
        }
    } else {
        let (is_exercised) = uint256_lt(instrument.strike_price, expiry_price);
        if (is_exercised == TRUE) {
            // call option exercised: otoken profit amount = option_token_amount *  (expiry_price - instrument.strike_price) / expiry_price
            let (r1) = SafeUint256.sub_le(expiry_price, instrument.strike_price);
            let (r2) = SafeUint256.mul(r1, option_token_amount);
            let (r3, _) = SafeUint256.div_rem(r2, expiry_price);
            let (r4) = convert_with_decimals(r3, OTOKEN_DECIMALS, underlying_asset_decimals);
            return (instrument.underlying_asset, r4, TRUE);
        } else {
            // call option not exercised: otoken profit amount = 0
            return (instrument.underlying_asset, Uint256(0, 0), FALSE);
        }
    }
}
