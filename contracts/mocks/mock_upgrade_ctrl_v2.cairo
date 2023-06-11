%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from openzeppelin.upgrades.library import Proxy, Proxy_initialized


const version = 2;

//
// Storage
//

@storage_var
func otoken_impl_class_hash() -> (value: felt) {
}

@storage_var
func oracle_contract() -> (value: felt) {
}

@storage_var
func pool_contract() -> (value: felt) {
}


//
// Event
//
@event
func oracle_updated(
    oracle: felt,
){
}

@event
func pool_updated(
    pool: felt,
){
}

//
// Initializer
//
@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    proxy_admin: felt,  _otoken_impl_class_hash: felt, _oracle: felt
) {
    Proxy.initializer(proxy_admin);
    otoken_impl_class_hash.write(_otoken_impl_class_hash);
    oracle_contract.write(_oracle);
    return ();
}

//
// Upgrades
//
@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_implementation: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(new_implementation);
    return ();
}

//
// Getters
//

@view
func get_version{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (val: felt) {
    return (version,);
}


@view
func getImplementationHash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    implementation: felt
) {
    return Proxy.get_implementation_hash();
}

@view
func getAdmin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (admin: felt) {
    return Proxy.get_admin();
}

@view
func get_oracle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (value: felt) {
    return oracle_contract.read();
}

@view
func get_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (value: felt) {
    return pool_contract.read();
}


//
// Setters
//
@external
func set_oracle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(val: felt) {
    Proxy.assert_only_admin();
    oracle_contract.write(val);
    oracle_updated.emit(val);
    return ();
}


@external
func set_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(val: felt) {
    Proxy.assert_only_admin();
    pool_contract.write(val);
    pool_updated.emit(val);
    return ();
}