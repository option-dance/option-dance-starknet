%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_le, uint256_check
from starkware.cairo.common.math import assert_nn_le, assert_not_zero, assert_nn, assert_lt
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_caller_address

from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.token.erc20.library import ERC20
from openzeppelin.access.ownable.library import Ownable
from contracts.lib.utils import felt_to_uint256, uint256_to_felt, uint256_to_felt_str
from contracts.lib.string import unsafe_literal_concat
from contracts.lib.time import timestamp_to_date
from contracts.lib.uint256 import convert_with_decimals
from contracts.lib.constant import (
    UNDERSCORE_STRING,
    TOKEN_TYPE_OPTION,
    TOKEN_TYPE_WRITER,
    OTOKEN_DECIMALS,
)
from starkware.starknet.common.syscalls import get_block_timestamp

@storage_var
func otoken_underlying_asset() -> (res: felt) {
}

@storage_var
func otoken_quote_asset() -> (res: felt) {
}

@storage_var
func otoken_strike_price() -> (res: Uint256) {
}

@storage_var
func otoken_expiry_timestamp() -> (res: felt) {
}

@storage_var
func otoken_option_type() -> (res: felt) {
}

@storage_var
func otoken_token_type() -> (res: felt) {
}

@storage_var
func otoken_option_id() -> (res: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _owner: felt,
    _underlying_asset: felt,
    _quote_asset: felt,
    _strike_price: Uint256,
    _expiry_timestamp: felt,
    _option_type: felt,
    _token_type: felt,
) {
    // check expiry timestamp and strike price
    alloc_locals;
    let (local block_timestamp) = get_block_timestamp();
    let (strike_price_felt) = uint256_to_felt(_strike_price);
    with_attr error_message("expiry timestamp must > block timestamp") {
        assert_nn_le(block_timestamp, _expiry_timestamp);
    }
    let (strike_price_valid) = uint256_le(_strike_price, Uint256(100000000, 0));
    with_attr error_message("strike price must > 10^8") {
        assert_lt(0, strike_price_felt);
    }

    let (name) = get_otoken_name(
        _underlying_asset, _quote_asset, _strike_price, _expiry_timestamp, _option_type, _token_type
    );
    ERC20.initializer(name, name, OTOKEN_DECIMALS);
    Ownable.initializer(_owner);
    otoken_underlying_asset.write(_underlying_asset);
    otoken_quote_asset.write(_quote_asset);
    otoken_strike_price.write(_strike_price);
    otoken_expiry_timestamp.write(_expiry_timestamp);
    otoken_option_type.write(_option_type);
    otoken_token_type.write(_token_type);
    return ();
}

@view
func get_otoken_name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _underlying_asset: felt,
    _quote_asset: felt,
    _strike_price: Uint256,
    _expiry_timestamp: felt,
    _option_type: felt,
    _token_type: felt,
) -> (name: felt) {
    alloc_locals;
    let (local underlying_symbol) = IERC20.symbol(_underlying_asset);
    let (local quote_symbol) = IERC20.symbol(_quote_asset);
    let (year, month, day) = timestamp_to_date(_expiry_timestamp);
    let (_strike_price_integer) = convert_with_decimals(_strike_price, 8, 0);
    let (strike_price_felt) = uint256_to_felt_str(_strike_price_integer);
    let (local concat) = unsafe_literal_concat(_token_type, underlying_symbol);
    let (local concat0) = unsafe_literal_concat(concat, UNDERSCORE_STRING);
    let (local concat1) = unsafe_literal_concat(concat0, strike_price_felt);
    let (local concat2) = unsafe_literal_concat(concat1, UNDERSCORE_STRING);
    let (local concat3) = unsafe_literal_concat(concat2, quote_symbol);
    let (local concat4) = unsafe_literal_concat(concat3, UNDERSCORE_STRING);
    let (local concat5) = unsafe_literal_concat(concat4, day);
    let (local concat6) = unsafe_literal_concat(concat5, UNDERSCORE_STRING);
    let (local concat7) = unsafe_literal_concat(concat6, month);
    let (local concat8) = unsafe_literal_concat(concat7, UNDERSCORE_STRING);
    let (local concat9) = unsafe_literal_concat(concat8, year);
    let (local concat10) = unsafe_literal_concat(concat9, UNDERSCORE_STRING);
    let (local concat11) = unsafe_literal_concat(concat10, _option_type);
    return (concat11,);
}

//
// Getters
//

@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    let (name) = ERC20.name();
    return (name,);
}

@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (symbol: felt) {
    let (symbol) = ERC20.symbol();
    return (symbol,);
}

@view
func totalSupply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    totalSupply: Uint256
) {
    let (totalSupply: Uint256) = ERC20.total_supply();
    return (totalSupply,);
}

@view
func decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    decimals: felt
) {
    let (decimals) = ERC20.decimals();
    return (decimals,);
}

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt) -> (
    balance: Uint256
) {
    let (balance: Uint256) = ERC20.balance_of(account);
    return (balance,);
}

@view
func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt
) -> (remaining: Uint256) {
    let (remaining: Uint256) = ERC20.allowance(owner, spender);
    return (remaining,);
}

@view
func owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
    let (owner: felt) = Ownable.owner();
    return (owner,);
}

@view
func underlying_asset{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    underlying_asset: felt
) {
    let (underlying_asset) = otoken_underlying_asset.read();
    return (underlying_asset,);
}

@view
func quote_asset{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    quote_asset: felt
) {
    let (quote_asset) = otoken_quote_asset.read();
    return (quote_asset,);
}

@view
func strike_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    strike_price: Uint256
) {
    let (strike_price) = otoken_strike_price.read();
    return (strike_price,);
}

@view
func option_type{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    option_type: felt
) {
    let (option_type) = otoken_option_type.read();
    return (option_type,);
}

@view
func token_type{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    token_type: felt
) {
    let (token_type) = otoken_token_type.read();
    return (token_type,);
}

@view
func expiry_timestamp{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    expiry_timestamp: felt
) {
    let (expiry_timestamp) = otoken_expiry_timestamp.read();
    return (expiry_timestamp,);
}

@view
func option_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    option_id: felt
) {
    let (option_id) = otoken_option_id.read();
    return (option_id,);
}

//
// Externals
//
@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) -> (success: felt) {
    ERC20.transfer(recipient, amount);
    return (TRUE,);
}

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) -> (success: felt) {
    ERC20.transfer_from(sender, recipient, amount);
    return (TRUE,);
}

@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) -> (success: felt) {
    ERC20.approve(spender, amount);
    return (TRUE,);
}

@external
func increaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, added_value: Uint256
) -> (success: felt) {
    ERC20.increase_allowance(spender, added_value);
    return (TRUE,);
}

@external
func decreaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, subtracted_value: Uint256
) -> (success: felt) {
    ERC20.decrease_allowance(spender, subtracted_value);
    return (TRUE,);
}

@external
func mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    to: felt, amount: Uint256
) {
    Ownable.assert_only_owner();
    ERC20._mint(to, amount);
    return ();
}

@external
func burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt, amount: Uint256
) {
    Ownable.assert_only_owner();
    ERC20._burn(account, amount);
    return ();
}

@external
func set_option_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_id: felt
) {
    Ownable.assert_only_owner();
    otoken_option_id.write(option_id);
    return ();
}

@external
func transferOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    newOwner: felt
) {
    Ownable.transfer_ownership(newOwner);
    return ();
}

@external
func renounceOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.renounce_ownership();
    return ();
}
