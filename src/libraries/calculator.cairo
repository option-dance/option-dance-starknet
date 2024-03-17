use starknet::{ContractAddress};
use optiondance::libraries::types::{Instrument};
use optiondance::libraries::erc20::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use optiondance::libraries::constant::{UNDERSCORE_STRING,
     TOKEN_TYPE_OPTION, TOKEN_TYPE_WRITER, OPTION_TYPE_PUT, OPTION_TYPE_CALL, OTOKEN_DECIMALS};

use optiondance::libraries::math::{u256_pow, u256_div_rem, mul_with_decimals, convert_with_decimals, u256_to_felt};



fn get_fully_collateralized_margin(option_amount: u256, instrument: Instrument) -> (ContractAddress, u256) {
    let quote_asset_decimals = IERC20Dispatcher{ contract_address: instrument.quote_asset}.decimals();
    let underlying_asset_decimals  = IERC20Dispatcher{ contract_address: instrument.underlying_asset}.decimals();
    if OPTION_TYPE_PUT == instrument.option_type {
        let strike_price_integer = convert_with_decimals(instrument.strike_price, 8, 0);
        let quote_amount0 = option_amount * strike_price_integer;
        let quote_amount1 = convert_with_decimals(
            quote_amount0, OTOKEN_DECIMALS, quote_asset_decimals
        );
        return (instrument.quote_asset, quote_amount1);
    } else {
        let underlying_amount = convert_with_decimals(
            option_amount, OTOKEN_DECIMALS, underlying_asset_decimals
        );
        return (instrument.underlying_asset, underlying_amount);
    }
}



fn get_writer_token_amount(option_token_amount: u256, instrument: Instrument) -> u256 {
    if OPTION_TYPE_PUT == instrument.option_type {
        let strike_price_integer = convert_with_decimals(instrument.strike_price, 8, 0);
        let writer_token_amount = option_token_amount * strike_price_integer;
        return writer_token_amount;
    } else {
        return option_token_amount;
    }
}



fn get_expired_cash_value(
        writer_token_amount: u256, 
        instrument: Instrument, 
        expiry_price: u256
    ) -> (
        ContractAddress, u256, bool
    ) {
    let quote_asset_decimals = IERC20Dispatcher{ contract_address: instrument.quote_asset}.decimals();
    let underlying_asset_decimals  = IERC20Dispatcher{ contract_address: instrument.underlying_asset}.decimals();
    

    if OPTION_TYPE_PUT == instrument.option_type {
        let is_exercised = expiry_price < instrument.strike_price;
        if is_exercised {
            // put option exercised: collateral amount can withdraw = (writer_token_amount * expiry_price) / instrument.strike_price)
            let r1 = writer_token_amount * expiry_price;
            let (r2, _ )= u256_div_rem(r1, instrument.strike_price);
            let r3 = convert_with_decimals(r2, OTOKEN_DECIMALS, quote_asset_decimals);
            return (instrument.quote_asset, r3, true); 
        } else {
            // put option not exercised: collateral amount can withdraw = writer_token_amount
            let r1 = convert_with_decimals(
                writer_token_amount, OTOKEN_DECIMALS, quote_asset_decimals
            );
            return (instrument.quote_asset, r1, false);
        }
    } else {
        let is_exercised = instrument.strike_price < expiry_price;
        if is_exercised {
            // call option exercised: collateral amount can withdraw = (writer_token_amount * instrument.strike_price) / expiry_price)
            let r1 = writer_token_amount * instrument.strike_price;
            let (r2, _) = u256_div_rem(r1, expiry_price);
            let r3 = convert_with_decimals(r2, OTOKEN_DECIMALS, underlying_asset_decimals);
            return (instrument.underlying_asset, r3, true);
        }else {
            // call option not exercised: collateral amount can withdraw = writer_token_amount
            let r1 = convert_with_decimals(
                writer_token_amount, OTOKEN_DECIMALS, underlying_asset_decimals
            );
            return (instrument.underlying_asset, r1, false);
        }
    }
}


fn get_expired_otoken_profit(
    option_token_amount: u256, 
    instrument: Instrument, 
    expiry_price: u256) -> (ContractAddress, u256, bool) {

        let quote_asset_decimals = IERC20Dispatcher{ contract_address: instrument.quote_asset}.decimals();
        let underlying_asset_decimals  = IERC20Dispatcher{ contract_address: instrument.underlying_asset}.decimals();

        if OPTION_TYPE_PUT == instrument.option_type {
            let is_exercised = expiry_price < instrument.strike_price;
            if is_exercised {
                // put option exercised: otoken profit amount = ( option_token_amount * ( instrument.strike_price - expiry_price))
                let r1 = instrument.strike_price - expiry_price;
                let r2 = r1 * option_token_amount;
                let r3 = convert_with_decimals(r2, 8, 0);
                let r4 = convert_with_decimals(r3, OTOKEN_DECIMALS, quote_asset_decimals);
                return (instrument.quote_asset, r4, true);
            } else {
                // put option not exercised: otoken profit amount = 0
                return (instrument.quote_asset, u256{low:0, high:0}, false);
            }
        } else {
            let is_exercised = instrument.strike_price < expiry_price;
            if is_exercised  {
                // call option exercised: otoken profit amount = option_token_amount *  (expiry_price - instrument.strike_price) / expiry_price
                let r1 = expiry_price - instrument.strike_price;
                let r2 = r1 * option_token_amount;
                let (r3, _) = u256_div_rem(r2, expiry_price);
                let r4 =  convert_with_decimals(r3, OTOKEN_DECIMALS, underlying_asset_decimals);
                return (instrument.underlying_asset, r4, true);
            }else {
                // call option not exercised: otoken profit amount = 0
                return (instrument.underlying_asset, u256{low:0, high:0}, false);
            }
        }
}