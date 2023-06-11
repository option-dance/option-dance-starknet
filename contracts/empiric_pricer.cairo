%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from openzeppelin.access.ownable.library import Ownable
from contracts.interfaces.oracle_interface import IOracle
from contracts.interfaces.IEmpiricOracle import IEmpiricOracle
from contracts.lib.uint256 import  convert_with_decimals
from starkware.cairo.common.math import assert_nn_le, assert_not_zero
from starkware.cairo.common.uint256 import Uint256



@storage_var
func oracle() -> (value: felt) {
}

@storage_var
func empiric_oracle() -> (value: felt) {
}

@storage_var
func asset_pair_id(asset: felt) -> (pair_id: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _owner: felt, _empiric_oracle: felt, _oracle: felt
) {
    Ownable.initializer(_owner);
    oracle.write(_oracle);
    empiric_oracle.write(_empiric_oracle);
    return ();
}


// view
@view
func get_spot_median{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(pair_id: felt) -> (
    price: felt, decimals: felt, last_updated_timestamp: felt, num_sources_aggregated: felt
) {
    let (_empiric_oracle) = empiric_oracle.read();
    let (
        price,
        decimals,
        last_updated_timestamp,
        num_sources_aggregated
    ) = IEmpiricOracle.get_spot_median(_empiric_oracle, pair_id);
    return (price, decimals, last_updated_timestamp, num_sources_aggregated);
}

@view
func get_oracle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (oracle: felt) {
    let (_oracle) = oracle.read();
    return (_oracle,);
}

@view
func get_empiric_oracle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (empiric_oracle: felt) {
    let (_empiric_oracle) = empiric_oracle.read();
    return (_empiric_oracle,);
}



// external
@external
func set_expiry_price_in_oracle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    asset: felt, expiry_timestamp: felt
) {
    Ownable.assert_only_owner();
    let (pair_id) = asset_pair_id.read(asset);
    assert_not_zero(pair_id);
    let (price, decimals, last_updated_timestamp, num_sources_aggregated) =  get_spot_median(pair_id);

    // check timestamp
    assert_nn_le(expiry_timestamp, last_updated_timestamp);

    let (expiry_price) = convert_with_decimals(Uint256(price, 0), decimals, 8);
    let (_oracle) = get_oracle();
    IOracle.set_expiry_price(_oracle, asset, expiry_timestamp, expiry_price);
    return ();
}


@external
func transferOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_owner: felt
) {
    Ownable.transfer_ownership(new_owner);
    return ();
}

@external
func set_oracle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _oracle: felt
) {
    Ownable.assert_only_owner();
    oracle.write(_oracle);
    return ();
}

@external
func set_empiric_oracle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _empiric_oracle: felt
) {
    Ownable.assert_only_owner();
    empiric_oracle.write(_empiric_oracle);
    return ();
}


@external
func bind_asset_pair_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    asset: felt, pair_id: felt
) {
    Ownable.assert_only_owner();
    asset_pair_id.write(asset, pair_id);
    return ();
}