//https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary/blob/master/contracts/BokkyPooBahsDateTimeLibrary.sol
use traits::TryInto;
use traits::Into;
use option::OptionTrait;

use optiondance::libraries::math::{u256_div_rem, u128_div_rem};
use optiondance::libraries::string::felt_to_string;


// 365 * 24 * 60 * 60
const SECONDS_IN_YEAR: u128 = 31104000;
// 24 * 60 * 60
const SECONDS_IN_DAY: u128 = 86400;
const OFFSET19700101: u128 = 2440588;


fn timestamp_to_days(_timestamp: u256) -> u256 {
    let timestamp: u256 = _timestamp.into();
    let (days, _) = u256_div_rem(timestamp, 86400);
    return days;
}



fn is_timestamp_utc_hour8(_timestamp: u256) -> bool {
    let timestamp: u256 = _timestamp.into();
    let seconds_per_day = 86400;
    let utc_offset = 28800;
    let (_, remainder) = u256_div_rem(timestamp, seconds_per_day);
    remainder == utc_offset
}

fn timestamp_to_date(_timestamp: u256) -> (felt252, felt252, felt252) {
    let timestamp: u256 = _timestamp.into();
    let (days, _) = u256_div_rem(timestamp, 86400);
    let (year_, month_, day_) = days_to_date(days);
    let year = felt_to_string(year_);
    let month = felt_to_string(month_);
    let day = felt_to_string(day_);
    return (year, month, day);
}

// function _daysToDate(uint _days) internal pure returns (uint year, uint month, uint day) {
//         int __days = int(_days);

//         int L = __days + 68569 + OFFSET19700101;
//         int N = 4 * L / 146097;
//         L = L - (146097 * N + 3) / 4;
//         int _year = 4000 * (L + 1) / 1461001;
//         L = L - 1461 * _year / 4 + 31;
//         int _month = 80 * L / 2447;
//         int _day = L - 2447 * _month / 80;
//         L = _month / 11;
//         _month = _month + 2 - 12 * L;
//         _year = 100 * (N - 49) + _year + L;

//         year = uint(_year);
//         month = uint(_month);
//         day = uint(_day);
//     }

// fn days_to_date(days: u256) -> (u256, u256, u256) {
fn days_to_date(_days: u256) ->  (u256, u256, u256)  {
    let days: u128 = _days.try_into().unwrap();
    let mut L: u128 = days + 68569 + OFFSET19700101; 
    let N: u128 = 4 * L / 146097; 
    L = L - (146097 * N + 3) / 4; 
    let mut _year: u128 = 4000 * (L + 1) / 1461001; 
    L = L - (1461 * _year / 4) + 31;
    let mut _month: u128 = 80 * L / 2447;   
    let _day: u128 = L - (2447 * _month / 80); 
    L = _month / 11; 
    _month = _month + 2 - 12 * L;
    _year = 100 * (N - 49) + _year + L;

    return (_year.into(), _month.into(), _day.into());
}