%lang starknet

// https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary/blob/master/contracts/BokkyPooBahsDateTimeLibrary.sol

from starkware.cairo.common.math import split_felt
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem
from starkware.cairo.common.math import unsigned_div_rem
from contracts.lib.utils import felt_to_uint256, uint256_to_felt
from contracts.lib.string import felt_to_string

const SECONDS_IN_YEAR = 365 * 24 * 60 * 60;
const SECONDS_IN_DAY = 24 * 60 * 60;
const OFFSET19700101 = 2440588;

func timestamp_to_date{range_check_ptr}(timestamp: felt) -> (year: felt, month: felt, day: felt) {
    alloc_locals;
    let (days, _) = unsigned_div_rem(timestamp, SECONDS_IN_DAY);
    let (year_, month_, day_) = days_to_date(days);
    let (year) = felt_to_string(year_);
    let (month) = felt_to_string(month_);
    let (day) = felt_to_string(day_);
    return (year, month, day);
}

//
// function _daysToDate(uint _days) internal pure returns (uint year, uint month, uint day) {
//     int __days = int(_days);

// int L = __days + 68569 + OFFSET19700101;
//     int N = 4 * L / 146097;
//     L = L - (146097 * N + 3) / 4;
//     int _year = 4000 * (L + 1) / 1461001;
//     L = L - 1461 * _year / 4 + 31;
//     int _month = 80 * L / 2447;
//     int _day = L - 2447 * _month / 80;
//     L = _month / 11;
//     _month = _month + 2 - 12 * L;
//     _year = 100 * (N - 49) + _year + L;

// year = uint(_year);
//     month = uint(_month);
//     day = uint(_day);
// }
//
func days_to_date{range_check_ptr}(days: felt) -> (year: felt, month: felt, day: felt) {
    alloc_locals;
    // int L = __days + 68569 + OFFSET19700101;
    local L = days + 68569;
    let L0 = L + OFFSET19700101;
    // int N = 4 * L / 146097;
    let (N, _) = unsigned_div_rem(4 * L0, 146097);
    // L = L - (146097 * N + 3) / 4;
    let N0 = 146097 * N;
    let N1 = N0 + 3;
    let (N2, _) = unsigned_div_rem(N1, 4);
    let L1 = L0 - N2;
    // int _year = 4000 * (L + 1) / 1461001;
    let l0 = L1 + 1;
    let l1 = l0 * 4000;
    let (year, _) = unsigned_div_rem(l1, 1461001);
    // L = L - 1461 * _year / 4 + 31;
    let y1 = 1461 * year;
    let (y2, _) = unsigned_div_rem(y1, 4);
    local y3 = y2 - 31;
    let L2 = L1 - y3;
    // int _month = 80 * L / 2447;
    let l2 = 80 * L2;
    let (month, _) = unsigned_div_rem(l2, 2447);
    // int _day = L - 2447 * _month / 80;
    let m1 = 2447 * month;
    let (m2, _) = unsigned_div_rem(m1, 80);
    let day = L2 - m2;
    // L = _month / 11;
    let (L3, _) = unsigned_div_rem(month, 11);
    // _month = _month + 2 - 12 * L;
    let m3 = month + 2;
    local l3 = 12 * L3;
    let month0 = m3 - l3;
    // _year = 100 * (N - 49) + _year + L;
    let N3 = N - 49;
    local N4 = N3 * 100;
    let year0 = N4 + year;
    let year1 = year0 + L3;
    return (year1, month0, day);
}
