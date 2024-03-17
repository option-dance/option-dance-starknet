use optiondance::libraries::time::{
    timestamp_to_date, timestamp_to_days, days_to_date, is_timestamp_utc_hour8,
};


#[test]
#[available_gas(3000000)]
fn test_timestamp_to_days() {
    let days = timestamp_to_days(1687865658);
    assert(days == 19535, 'year Should return 19535');
}

#[test]
#[available_gas(3000000)]
fn test_is_utc_hour8() {
    let ishour8 = is_timestamp_utc_hour8(1693305775);
    assert(ishour8 == false, 'ishour8 Should return false');
    let ishour8 = is_timestamp_utc_hour8(1693296000);
    assert(ishour8 == true, 'ishour8 Should return true');
}


#[test]
#[available_gas(3000000)]
fn test_days_to_date() {
    let (year, month, day) = days_to_date(19535);
    assert(year == 2023, 'invalid');
    assert(month == 6, 'invalid');
    assert(day == 27, 'invalid');
}


#[test]
#[available_gas(3000000)]
fn test_timestamp_to_date() {
    let (year, month, day) = timestamp_to_date(1687865658);
    assert(year == 842019379, 'invalid');
    assert(month == 54, 'invalid');
    assert(day == 12855, 'invalid');
}
