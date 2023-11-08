use optiondance::libraries::string::{felt_to_string, unsafe_literal_concat};

#[test]
#[available_gas(30000000)]
fn test_felt_to_string() {
    assert(felt_to_string(1) == 49, 'invalid');
    assert(felt_to_string(3671283321132123) == 68072131245641946372917638911375782451, 'invalid');
}


#[test]
#[available_gas(3000000)]
fn test_literal_concat() {
    assert(unsafe_literal_concat(49, 50) == 12594, 'invalid');
}