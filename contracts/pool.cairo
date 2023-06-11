%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from openzeppelin.access.ownable.library import Ownable
from contracts.types import ExpiryPrice, Instrument
from contracts.interfaces.IEmpiricOracle import IEmpiricOracle, EmpiricAggregationModes
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_lt, uint256_add
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_block_timestamp, get_caller_address, get_contract_address
from starkware.cairo.common.math_cmp import is_le, is_not_zero
from starkware.cairo.common.math import assert_le
from openzeppelin.token.erc20.IERC20 import IERC20


@event
func event_deposit(
    asset :felt,
    user: felt,
    amount: Uint256
) {
}

@event
func event_withdraw(
    asset :felt,
    user: felt,
    amount: Uint256
) {
}


@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _owner: felt
) {
    Ownable.initializer(_owner);
    return ();
}


@external
func deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    asset :felt,
    user: felt,
    amount: Uint256
) {
    alloc_locals;
    Ownable.assert_only_owner();
    let (current_address) = get_contract_address();
    let (is_amount_valid) = uint256_lt(Uint256(0, 0), amount);
    with_attr error_message("deposit amount should > 0") {
        assert is_amount_valid = TRUE;
    }
    IERC20.transferFrom(asset, user, current_address, amount);
    event_deposit.emit(asset, user, amount);
    return ();
}



@external
func withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    asset :felt,
    user: felt,
    amount: Uint256
) {
    alloc_locals;
    Ownable.assert_only_owner();
    let (is_amount_valid) = uint256_lt(Uint256(0, 0), amount);
    with_attr error_message("withdraw amount should > 0") {
        assert is_amount_valid = TRUE;
    }
    IERC20.transfer(asset, user, amount);
    event_withdraw.emit(asset, user, amount);
    return ();
}