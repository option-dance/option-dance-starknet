%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import deploy
from starkware.cairo.common.uint256 import Uint256, uint256_lt
from starkware.cairo.common.alloc import alloc
from contracts.interfaces.otoken_interface import IOtoken
from contracts.interfaces.oracle_interface import IOracle
from contracts.interfaces.pool_interface import IPool
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.math_cmp import is_not_zero
from contracts.types import Instrument
from contracts.calculator import (
    get_fully_collateralized_margin,
    get_writer_token_amount,
    get_expired_cash_value,
    get_expired_otoken_profit,
)
from contracts.lib.time import timestamp_to_date
from contracts.lib.utils import felt_to_uint256, uint256_to_felt, uint256_to_felt_str
from contracts.lib.uint256 import convert_with_decimals
from contracts.lib.string import unsafe_literal_concat
from contracts.lib.constant import (
    TOKEN_TYPE_OPTION,
    TOKEN_TYPE_WRITER,
    OPTION_TYPE_CALL,
    OPTION_TYPE_PUT,
    UNDERSCORE_STRING,
)
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address
from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.upgrades.library import Proxy
from starkware.cairo.common.bool import TRUE, FALSE
from openzeppelin.access.ownable.library import Ownable

@storage_var
func salt() -> (value: felt) {
}

@storage_var
func otoken_impl_class_hash() -> (value: felt) {
}

@storage_var
func instruments(id: felt) -> (value: Instrument) {
}

@storage_var
func oracle_contract() -> (value: felt) {
}

@storage_var
func pool_contract() -> (value: felt) {
}

@storage_var
func instrument_name_status(name: felt) -> (status: felt) {
}


@storage_var
func allowed_underlying_asset(asset: felt) -> (allowed: felt) {
}

@storage_var
func allowed_quote_asset(asset: felt) -> (allowed: felt) {
}

@storage_var
func is_paused() -> (is_paused: felt) {
}




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


@event
func is_paused_updated(
    is_paused: felt,
){
}


@event
func underlying_asset_allowed(
    asset: felt,
    allowed: felt,
){
}

@event
func quote_asset_allowed(
    asset: felt,
    allowed: felt,
){
}


@event
func instrument_created(instrument: Instrument) {
}

@event
func otoken_created(
    option_id: felt,
    otoken_address: felt,
    underlying_asset: felt,
    quote_asset: felt,
    strike_price: Uint256,
    expiry_timestamp: felt,
    option_type: felt,
    token_type: felt,
) {
}

@event
func option_minted(
    user: felt,
    instrument: Instrument,
    collateral_asset: felt,
    collateral_amount: Uint256,
    option_token_amount: Uint256,
    writer_token_amount: Uint256
){
}



@event
func position_closed(
    user: felt,
    instrument: Instrument,
    collateral_asset: felt,
    collateral_amount: Uint256,
    option_token_amount: Uint256,
    writer_token_amount: Uint256
){
}


@event
func settled(
    user: felt,
    instrument: Instrument,
    collateral_asset: felt,
    collateral_amount: Uint256,
    is_exercised: felt,
    writer_token_amount: Uint256,
){
}


@event
func exercised(
    user: felt,
    instrument: Instrument,
    profit_asset: felt,
    profit_amount: Uint256,
    is_exercised: felt,
    option_token_amount: Uint256
){
}

//
// Initializer
//
@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    proxy_admin: felt, _otoken_impl_class_hash: felt, _oracle: felt
) {
    Proxy.initializer(proxy_admin);
    otoken_impl_class_hash.write(_otoken_impl_class_hash);
    oracle_contract.write(_oracle);
    is_paused.write(FALSE);
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



// Returns the instrument.
@view
func get_instrument{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(id: felt) -> (
    res: Instrument
) {
    let (res) = instruments.read(id);
    return (res,);
}

@view
func get_oracle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    oracle: felt
) {
    let (oracle) = oracle_contract.read();
    return (oracle,);
}

@view
func get_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    pool: felt
) {
    let (pool) = pool_contract.read();
    return (pool,);
}

@view
func get_underlying_asset_allowed{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(asset: felt) -> (
    allowed: felt
) {
    let (allowed) = allowed_underlying_asset.read(asset);
    return (allowed,);
}

@view
func get_quote_asset_allowed{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(asset: felt) -> (
    allowed: felt
) {
    let (allowed) = allowed_quote_asset.read(asset);
    return (allowed,);
}


@view
func get_instrument_name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _underlying_asset: felt,
    _quote_asset: felt,
    _strike_price: Uint256,
    _expiry_timestamp: felt,
    _option_type: felt,
) -> (name: felt) {
    alloc_locals;
    let (local underlying_symbol) = IERC20.symbol(_underlying_asset);
    let (local quote_symbol) = IERC20.symbol(_quote_asset);
    let (year, month, day) = timestamp_to_date(_expiry_timestamp);

    let (strike_price_felt) = uint256_to_felt_str(_strike_price);
    let (local concat0) = unsafe_literal_concat(underlying_symbol, UNDERSCORE_STRING);
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




@external
func setAdmin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(new_admin: felt) {
    Proxy.assert_only_admin();
    Proxy._set_admin(new_admin);
    return ();
}

@external
func set_oracle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (oracle: felt) {
    Proxy.assert_only_admin();
    oracle_contract.write(oracle);
    oracle_updated.emit(oracle);
    return ();
}

@external
func set_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (pool: felt) {
    Proxy.assert_only_admin();
    pool_contract.write(pool);
    pool_updated.emit(pool);
    return ();
}

@external
func allow_underlying_asset{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (asset: felt, allowed: felt) {
    Proxy.assert_only_admin();
    allowed_underlying_asset.write(asset, allowed);
    underlying_asset_allowed.emit(asset, allowed);
    return ();
}

@external
func allow_quote_asset{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (asset: felt, allowed: felt) {
    Proxy.assert_only_admin();
    allowed_quote_asset.write(asset, allowed);
    quote_asset_allowed.emit(asset, allowed);
    return ();
}

@external
func set_is_paused{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (_is_paused: felt) {
    Proxy.assert_only_admin();
    is_paused.write(_is_paused);
    is_paused_updated.emit(_is_paused);
    return ();
}


@external
func create_instrument{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _underlying_asset: felt,
    _quote_asset: felt,
    _strike_price: Uint256,
    _expiry: felt,
    _option_type: felt,
) -> (res: Instrument) {
    alloc_locals;
    assert_not_paused();
    let (current_salt) = salt.read();
    let (class_hash) = otoken_impl_class_hash.read();

    let (underlying_asset_allowed) = allowed_underlying_asset.read(_underlying_asset);
    with_attr error_message("underlying asset is not allowed") {
        assert underlying_asset_allowed = TRUE;
    }
    let (quote_asset_allowed) = allowed_quote_asset.read(_quote_asset);
    with_attr error_message("quote asset is not allowed") {
        assert quote_asset_allowed = TRUE;
    }

    //check strike price > 10 ^ 8
    let (is_strike_price_invalid) = uint256_lt(_strike_price, Uint256(100000000,0));
    with_attr error_message("strike price should greater than 10^8") {
        assert is_strike_price_invalid = FALSE;
    }

    let (_strike_price_integer) = convert_with_decimals(_strike_price, 8, 0);
    let (strike_price) = convert_with_decimals(_strike_price_integer, 0, 8);

    let (instrument_name) = get_instrument_name(
        _underlying_asset, _quote_asset, _strike_price_integer, _expiry, _option_type
    );
    let (status) = instrument_name_status.read(instrument_name);
    with_attr error_message("instrument already created") {
        assert_not_equal(1, status);
    }

    let (local option_token_calldata: felt*) = get_otoken_deploy_calldata(
        _underlying_asset, _quote_asset, strike_price, _expiry, _option_type, TOKEN_TYPE_OPTION
    );

    let (option_token_address) = deploy(
        class_hash=class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=8,
        constructor_calldata=option_token_calldata,
        deploy_from_zero=0,
    );
    let second_salt = current_salt + 1;
    let (local writer_token_calldata: felt*) = get_otoken_deploy_calldata(
        _underlying_asset, _quote_asset, strike_price, _expiry, _option_type, TOKEN_TYPE_WRITER
    );
    let (writer_token_address) = deploy(
        class_hash=class_hash,
        contract_address_salt=second_salt,
        constructor_calldata_size=8,
        constructor_calldata=writer_token_calldata,
        deploy_from_zero=0,
    );

    // bind option id
    IOtoken.set_option_id(contract_address=option_token_address, option_id=option_token_address);
    IOtoken.set_option_id(contract_address=writer_token_address, option_id=option_token_address);

    // save option
    salt.write(value=second_salt + 1);
    let new_instrument = Instrument(
        id=option_token_address,
        name=instrument_name,
        option_token=option_token_address,
        writer_token=writer_token_address,
        underlying_asset=_underlying_asset,
        quote_asset=_quote_asset,
        strike_price=strike_price,
        expiry_timestamp=_expiry,
        option_type=_option_type,
    );
    instruments.write(option_token_address, new_instrument);

    // events
    instrument_created.emit(new_instrument);
    otoken_created.emit(
        option_token_address,
        option_token_address,
        _underlying_asset,
        _quote_asset,
        strike_price,
        _expiry,
        _option_type,
        TOKEN_TYPE_OPTION,
    );
    otoken_created.emit(
        option_token_address,
        writer_token_address,
        _underlying_asset,
        _quote_asset,
        strike_price,
        _expiry,
        _option_type,
        TOKEN_TYPE_WRITER,
    );

    // update instrument name status
    instrument_name_status.write(instrument_name, 1);
    return (res=new_instrument);
}

func get_otoken_deploy_calldata{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _underlying_asset: felt,
    _quote_asset: felt,
    _strike_price: Uint256,
    _expiry: felt,
    _option_type: felt,
    _token_type: felt,
) -> (res: felt*) {
    alloc_locals;
    let (local call_data_array: felt*) = alloc();
    let (contract_address) = get_contract_address();
    assert call_data_array[0] = contract_address;
    assert call_data_array[1] = _underlying_asset;
    assert call_data_array[2] = _quote_asset;
    assert call_data_array[3] = _strike_price.low;
    assert call_data_array[4] = _strike_price.high;
    assert call_data_array[5] = _expiry;
    assert call_data_array[6] = _option_type;
    assert call_data_array[7] = _token_type;
    return (call_data_array,);
}


@view
func get_instrument_by_otoken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token: felt
) -> (res: Instrument) {
    let (instrument_id) = IOtoken.option_id(contract_address=option_token);
    let (instrument) = instruments.read(instrument_id);
    return (instrument,);
}

@external
func mint_option{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token: felt, option_token_amount: Uint256
) {
    alloc_locals;
    assert_not_paused();
    let (current_address) = get_contract_address();
    let (caller_address) = get_caller_address();
    let (instrument) = get_instrument_by_otoken(option_token);
    let (pool) = get_pool();
    // option seller deposit collateral (fully collaterized)
    // mint option token and writer token to option seller
    // get collateral asset, put option is quote asset, call option is underlying asset
    let (collateral_asset, collateral_amount) = get_fully_collateralized_margin(option_token_amount, instrument);
    IPool.deposit(pool, collateral_asset, caller_address, collateral_amount);
    IOtoken.mint(instrument.option_token, caller_address, option_token_amount);
    let (writer_token_amount) = get_writer_token_amount(option_token_amount, instrument);
    IOtoken.mint(instrument.writer_token, caller_address, writer_token_amount);
    option_minted.emit(caller_address, instrument, collateral_asset, collateral_amount, option_token_amount, writer_token_amount);
    return ();
}

@external
func close_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token: felt, option_token_amount: Uint256
) {
    alloc_locals;
    assert_not_paused();
    let (current_address) = get_contract_address();
    let (caller_address) = get_caller_address();
    let (pool) = get_pool();
    let (instrument) = get_instrument_by_otoken(option_token);
    let (collateral_asset, collateral_amount) = get_fully_collateralized_margin(option_token_amount, instrument);
    let (writer_token_amount) = get_writer_token_amount(option_token_amount, instrument);
    IOtoken.burn(instrument.option_token, caller_address, option_token_amount);
    IOtoken.burn(instrument.writer_token, caller_address, writer_token_amount);
    IPool.withdraw(pool, collateral_asset, caller_address, collateral_amount);
    position_closed.emit(caller_address, instrument, collateral_asset, collateral_amount, option_token_amount, writer_token_amount);
    return ();
}

@external
func settle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    writer_token: felt, writer_token_amount: Uint256
) {
    alloc_locals;
    assert_not_paused();
    let (current_address) = get_contract_address();
    let (caller_address) = get_caller_address();
    let (option_id) = IOtoken.option_id(writer_token);
    let (instrument) = get_instrument_by_otoken(option_id);

    let (oracle) = get_oracle();
    let (pool) = get_pool();
    let (price, settle_enabled) = IOracle.get_expiry_price(
        oracle, instrument.underlying_asset, instrument.expiry_timestamp
    );
    with_attr error_message("settle is not allowed before expiry and dispute time") {
        assert settle_enabled = TRUE;
    }
    let (collateral_asset, collateral_amount, is_exercised) = get_expired_cash_value(
        writer_token_amount, instrument, price
    );
    IOtoken.burn(instrument.writer_token, caller_address, writer_token_amount);
    IPool.withdraw(pool, collateral_asset, caller_address, collateral_amount);
    settled.emit(caller_address, instrument, collateral_asset, collateral_amount, is_exercised, writer_token_amount);
    return (); 
}

@external
func exercise{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    option_token: felt, option_token_amount: Uint256
) {
    alloc_locals;
    assert_not_paused();
    let (current_address) = get_contract_address();
    let (caller_address) = get_caller_address();
    let (instrument) = get_instrument_by_otoken(option_token);

    let (oracle) = get_oracle();
    let (pool) = get_pool();
    let (price, settle_enabled) = IOracle.get_expiry_price(
        oracle, instrument.underlying_asset, instrument.expiry_timestamp
    );
    with_attr error_message("exercise is not allowed before expiry and dispute time") {
        assert settle_enabled = TRUE;
    }
    let (profit_asset, profit_amount, is_exercised) = get_expired_otoken_profit(
        option_token_amount, instrument, price
    );
    IOtoken.burn(instrument.option_token, caller_address, option_token_amount);
    exercised.emit(caller_address, instrument, profit_asset, profit_amount, is_exercised, option_token_amount);
    if (is_exercised == FALSE) {
        return ();
    }
    IPool.withdraw(pool, profit_asset, caller_address, profit_amount);
    return ();
}



func assert_not_paused{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (paused) = is_paused.read();
    with_attr error_message("system is paused") {
        assert paused = FALSE;
    }
    return ();
}