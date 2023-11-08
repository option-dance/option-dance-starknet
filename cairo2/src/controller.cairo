use starknet::{ContractAddress, ClassHash};
use optiondance::libraries::types::{Instrument};

#[starknet::interface]
trait IController<TContractState> {
    fn get_instrument(self: @TContractState, id: felt252) -> Instrument;
    fn get_oracle(self: @TContractState) -> ContractAddress;
    fn get_pool_balance(self: @TContractState, asset: ContractAddress) -> u256;
    fn get_otoken_impl_class_hash(self: @TContractState) -> ClassHash;
    fn get_underlying_asset_allowed(self: @TContractState, asset: ContractAddress) -> bool;
    fn get_quote_asset_allowed(self: @TContractState, asset: ContractAddress) -> bool;
    fn get_instrument_name(
        self: @TContractState, 
        _underlying_asset: ContractAddress,
        _quote_asset: ContractAddress,
        _strike_price: u256,
        _expiry_timestamp: felt252,
        _option_type: felt252
    ) -> felt252;

    fn get_instrument_by_otoken(self: @TContractState, option_token: ContractAddress) -> Instrument;


    fn owner(self: @TContractState) -> ContractAddress;
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);

    fn set_oracle(ref self: TContractState, oracle: ContractAddress);
    fn set_otoken_impl_class_hash(ref self: TContractState, otoken_impl_class_hash: ClassHash);
    fn allow_underlying_asset(ref self: TContractState, asset: ContractAddress, allowed: bool);
    fn allow_quote_asset(ref self: TContractState, asset: ContractAddress, allowed: bool);
    fn set_is_paused(ref self: TContractState, is_paused: bool);

    fn create_instrument(
        ref self: TContractState, 
        _underlying_asset: ContractAddress,
        _quote_asset: ContractAddress,
        _strike_price: u256,
        _expiry_timestamp: felt252,
        _option_type: felt252
    ) -> Instrument;

    fn mint_option(ref self: TContractState, option_token: ContractAddress, option_token_amount: u256);
    fn close_position(ref self: TContractState, option_token: ContractAddress, option_token_amount: u256);
    fn settle(ref self: TContractState, writer_token: ContractAddress, writer_token_amount: u256);
    fn exercise(ref self: TContractState, option_token: ContractAddress, option_token_amount: u256);
}



#[starknet::contract]
mod Controller {
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;
    use array::ArrayTrait;
    use zeroable::Zeroable;

    use starknet::{ContractAddress,get_caller_address,get_contract_address,  
    get_block_timestamp,contract_address_to_felt252, replace_class_syscall, ClassHash};
    use starknet::syscalls::deploy_syscall;
    
    use optiondance::otoken::{IOtoken, IOtokenDispatcher, IOtokenDispatcherTrait};
    use optiondance::oracle::{IOracle, IOracleDispatcher, IOracleDispatcherTrait};
    use optiondance::libraries::erc20::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use optiondance::libraries::reentrancyguard::ReentrancyGuard;
    use optiondance::libraries::constant::{UNDERSCORE_STRING,
     TOKEN_TYPE_OPTION, TOKEN_TYPE_WRITER, OPTION_TYPE_PUT, OPTION_TYPE_CALL, OTOKEN_DECIMALS};
    use optiondance::libraries::string::{felt_to_string, unsafe_literal_concat};
    use optiondance::libraries::time::{timestamp_to_date, is_timestamp_utc_hour8};
    use optiondance::libraries::math::{u256_pow, u256_div_rem, mul_with_decimals, convert_with_decimals, u256_to_felt};
    use optiondance::libraries::types::{Instrument};
    use optiondance::libraries::calculator:: {
        get_fully_collateralized_margin, 
        get_writer_token_amount,
        get_expired_cash_value,
        get_expired_otoken_profit
    };


    #[storage]
    struct Storage {
        owner: ContractAddress,
        otoken_impl_class_hash: ClassHash,
        otoken_address_salt: felt252,
        instruments: LegacyMap<felt252, Instrument>,
        otoken_to_instrument: LegacyMap<ContractAddress, Instrument>,
        oracle: ContractAddress,
        pool_balance: LegacyMap<ContractAddress, u256>,
        instrument_name_status: LegacyMap<felt252, bool>,
        allowed_underlying_asset: LegacyMap<ContractAddress, bool>,
        allowed_quote_asset: LegacyMap<ContractAddress, bool>,
        is_paused: bool
    }

    //***********************************************************//
    //                      event
    //***********************************************************//
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        oracle_updated: oracle_updated,
        otoken_impl_class_hash_updated: otoken_impl_class_hash_updated,
        is_paused_updated: is_paused_updated,
        underlying_asset_allowed: underlying_asset_allowed,
        quote_asset_allowed: quote_asset_allowed,
        instrument_created: instrument_created,
        otoken_created: otoken_created,
        option_minted: option_minted,
        position_closed: position_closed,
        settled: settled,
        exercised: exercised,
        OwnershipTransferred: OwnershipTransferred,
    }


    #[derive(Drop, starknet::Event)]
    struct oracle_updated {oracle: ContractAddress}

    #[derive(Drop, starknet::Event)]
    struct otoken_impl_class_hash_updated{otoken_impl_class_hash: ClassHash}

    #[derive(Drop, starknet::Event)]
    struct is_paused_updated{is_paused: bool}

    #[derive(Drop, starknet::Event)]
    struct underlying_asset_allowed{asset: ContractAddress, allowed:   bool}

    #[derive(Drop, starknet::Event)]
    struct quote_asset_allowed{asset: ContractAddress, allowed:  bool }

    #[derive(Drop, starknet::Event)]
    struct instrument_created{instrument: Instrument}

    #[derive(Drop, starknet::Event)]
    struct otoken_created{
        option_id: felt252,
        otoken_address: ContractAddress,
        underlying_asset: ContractAddress,
        quote_asset: ContractAddress,
        strike_price: u256,
        expiry_timestamp: felt252,
        option_type: felt252,
        token_type: felt252,    }


    #[derive(Drop, starknet::Event)]
    struct option_minted{
        user: ContractAddress,
        instrument: Instrument,
        collateral_asset: ContractAddress,
        collateral_amount: u256,
        option_token_amount: u256,
        writer_token_amount: u256
    }


    #[derive(Drop, starknet::Event)]
    struct position_closed{
        user: ContractAddress,
        instrument: Instrument,
        collateral_asset: ContractAddress,
        collateral_amount: u256,
        option_token_amount: u256,
        writer_token_amount: u256
    }


    #[derive(Drop, starknet::Event)]
    struct settled{
        user: ContractAddress,
        instrument: Instrument,
        collateral_asset: ContractAddress,
        collateral_amount: u256,
        is_exercised: bool,
        writer_token_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct exercised{
        user: ContractAddress,
        instrument: Instrument,
        profit_asset: ContractAddress,
        profit_amount: u256,
        is_exercised: bool,
        option_token_amount: u256,
    }
    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress, 
        new_owner: ContractAddress, 
    }



    //***********************************************************//
    //                      constructor
    //***********************************************************//
    #[constructor]
    fn constructor(ref self: ContractState, _owner: ContractAddress,  _otoken_impl_class_hash: ClassHash, _oracle: ContractAddress) {
        self.otoken_impl_class_hash.write(_otoken_impl_class_hash);
        self.oracle.write(_oracle);
        self.is_paused.write(false);
        let caller = get_caller_address();
        self.ownable_initializer(_owner);
    }



    #[external(v0)]
    impl Controller of super::IController<ContractState> {

        //***********************************************************//
        //                      View
        //***********************************************************//
        fn get_instrument(self: @ContractState, id: felt252) -> Instrument {
            self.instruments.read(id)
        }
        fn get_oracle(self: @ContractState) -> ContractAddress {
            self.oracle.read()
        }
        fn get_pool_balance(self: @ContractState, asset: ContractAddress) -> u256 {
            self.pool_balance.read(asset)
        }
        fn get_otoken_impl_class_hash(self: @ContractState) -> ClassHash {
            self.otoken_impl_class_hash.read()
        }
        fn get_underlying_asset_allowed(self: @ContractState, asset: ContractAddress) -> bool {
            self.allowed_underlying_asset.read(asset)
        }
        fn get_quote_asset_allowed(self: @ContractState, asset: ContractAddress) -> bool {
            self.allowed_quote_asset.read(asset)
        }
        fn get_instrument_name(
            self: @ContractState,
            _underlying_asset: ContractAddress,
            _quote_asset: ContractAddress,
            _strike_price: u256,
            _expiry_timestamp: felt252,
            _option_type: felt252,
        ) -> felt252 {

            let instrument_name = self._get_instrument_name(
                _underlying_asset, _quote_asset, _strike_price, _expiry_timestamp, _option_type
            );
            return instrument_name;
        }

        fn get_instrument_by_otoken(self: @ContractState, option_token: ContractAddress) -> Instrument{
            self._get_instrument_by_otoken(option_token)
        }


        //***********************************************************//
        //                      Access
        //***********************************************************//
        fn owner(self: @ContractState) -> ContractAddress{
            self.owner.read()
        }
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.assert_only_owner();
            replace_class_syscall(new_class_hash);
        }
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            assert(!new_owner.is_zero(), 'New owner is the zero address');
            self.assert_only_owner();
            self._transfer_ownership(new_owner);
        }

        //***********************************************************//
        //                      External
        //***********************************************************//

        fn set_oracle(ref self: ContractState,oracle: ContractAddress) {
            self.assert_only_owner();
            self.oracle.write(oracle);
            self.emit(Event::oracle_updated(oracle_updated { oracle: oracle}));
        }

        fn set_otoken_impl_class_hash(ref self: ContractState, otoken_impl_class_hash: ClassHash){
            self.assert_only_owner();
            self.otoken_impl_class_hash.write(otoken_impl_class_hash);
            self.emit(Event::otoken_impl_class_hash_updated(otoken_impl_class_hash_updated { otoken_impl_class_hash: otoken_impl_class_hash}));
        }

        fn allow_underlying_asset(ref self: ContractState, asset: ContractAddress, allowed: bool) {
            self.assert_only_owner();
            self.allowed_underlying_asset.write(asset, allowed);
            self.emit(Event::underlying_asset_allowed(underlying_asset_allowed { asset: asset, allowed: allowed}));
        }
        fn allow_quote_asset(ref self: ContractState, asset: ContractAddress, allowed: bool) {
            self.assert_only_owner();
            self.allowed_quote_asset.write(asset, allowed);
            self.emit(Event::quote_asset_allowed(quote_asset_allowed { asset: asset, allowed: allowed}));
        }
        fn set_is_paused(ref self: ContractState, is_paused: bool) {
            self.assert_only_owner();
            self.is_paused.write(is_paused);
            self.emit(Event::is_paused_updated(is_paused_updated { is_paused: is_paused}));
        }

        fn create_instrument(
            ref self: ContractState,
            _underlying_asset: ContractAddress,
            _quote_asset: ContractAddress,
            _strike_price: u256,
            _expiry_timestamp: felt252,
            _option_type: felt252,
        ) -> Instrument {
            self.assert_not_paused();
            let mut unsafe_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref unsafe_state);            
            // check option type
            let mut type_check = 0;
            if  OPTION_TYPE_PUT == _option_type {
                type_check = type_check + 1;
            }
            if  OPTION_TYPE_CALL == _option_type {
                type_check = type_check + 1;
            }
            assert(type_check == 1, 'wrong option type');

            //check underlying asset and quote asset
            let underlying_asset_allowed = self.allowed_underlying_asset.read(_underlying_asset);
            assert(underlying_asset_allowed == true, 'underlying asset is not allowed');
            if OPTION_TYPE_PUT == _option_type {
                let quote_asset_allowed = self.allowed_quote_asset.read(_quote_asset);
                assert(quote_asset_allowed == true, 'quote asset is not allowed');
            } else {
                assert(_underlying_asset == _quote_asset, 'call option quote != underlying')
            }

            // check strike price and expiry timestamp
            assert(_strike_price > 100000000,  'strike price must > 10^8');
            let is_expiry_timestamp_utc8 = is_timestamp_utc_hour8(_expiry_timestamp.into());
            assert(is_expiry_timestamp_utc8 == true,  'expiry should at utc 8:00');

            let instrument_name = self._get_instrument_name(
                _underlying_asset, _quote_asset, _strike_price, _expiry_timestamp, _option_type
            );

            let status = self.instrument_name_status.read(instrument_name);
            assert(status == false,  'instrument already created');

            let class_hash =  self.otoken_impl_class_hash.read();
            let mut salt =  self.otoken_address_salt.read();

            let option_token_calldata = self.get_otoken_deploy_calldata(
                _underlying_asset, _quote_asset, _strike_price, _expiry_timestamp, _option_type, TOKEN_TYPE_OPTION
            );
            let (option_token_address, _) = deploy_syscall(
                class_hash,
                salt,
                option_token_calldata.span(),
                false,
            ).unwrap_syscall();

            salt = salt + 1;
            let writer_token_calldata = self.get_otoken_deploy_calldata(
                _underlying_asset, _quote_asset, _strike_price, _expiry_timestamp, _option_type, TOKEN_TYPE_WRITER
            );
            let (writer_token_address, _) = deploy_syscall(
                class_hash,
                salt,
                writer_token_calldata.span(),
                false,
            ).unwrap_syscall();


            // bind option id
            let option_id = contract_address_to_felt252(option_token_address);
            IOtokenDispatcher{ contract_address: option_token_address }.set_option_id(option_id);
            IOtokenDispatcher{ contract_address: option_token_address }.set_option_name(instrument_name);
            IOtokenDispatcher{ contract_address: writer_token_address }.set_option_id(option_id);
            IOtokenDispatcher{ contract_address: writer_token_address }.set_option_name(instrument_name);

            self.otoken_address_salt.write(salt + 1);

            let new_instrument = Instrument{
                id:option_id,
                name:instrument_name,
                option_token:option_token_address,
                writer_token:writer_token_address,
                underlying_asset:_underlying_asset,
                quote_asset:_quote_asset,
                strike_price:_strike_price,
                expiry_timestamp:_expiry_timestamp.try_into().unwrap(),
                option_type:_option_type,
            };
            self.instruments.write(instrument_name, new_instrument);
            self.otoken_to_instrument.write(option_token_address, new_instrument);
            self.otoken_to_instrument.write(writer_token_address, new_instrument);
            self.instrument_name_status.write(instrument_name, true);

            // events
            self.emit(Event::instrument_created(instrument_created { instrument: new_instrument}));

            self.emit(Event::otoken_created(otoken_created { 
                option_id: option_id,
                otoken_address: option_token_address,
                underlying_asset: _underlying_asset,
                quote_asset: _quote_asset,
                strike_price: _strike_price,
                expiry_timestamp: _expiry_timestamp,
                option_type: _option_type,
                token_type: TOKEN_TYPE_OPTION,
            }));
            self.emit(Event::otoken_created(otoken_created { 
                option_id: option_id,
                otoken_address: writer_token_address,
                underlying_asset: _underlying_asset,
                quote_asset: _quote_asset,
                strike_price: _strike_price,
                expiry_timestamp: _expiry_timestamp,
                option_type: _option_type,
                token_type: TOKEN_TYPE_WRITER,
            }));
            ReentrancyGuard::InternalImpl::end(ref unsafe_state);
            return new_instrument;
        }


        fn mint_option(ref self: ContractState, option_token: ContractAddress, option_token_amount: u256){
            self.assert_not_paused();
            let mut unsafe_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref unsafe_state);

            let contract_address = get_contract_address();
            let caller = get_caller_address();
            let instrument = self._get_instrument_by_otoken(option_token);
            // option seller deposit collateral (fully collaterized)
            // mint option token and writer token to option seller
            // get collateral asset, put option is quote asset, call option is underlying asset
            let (collateral_asset, collateral_amount) = get_fully_collateralized_margin(option_token_amount, instrument);
            let writer_token_amount = get_writer_token_amount(option_token_amount, instrument);

            IERC20Dispatcher{contract_address: collateral_asset}.transfer_from(caller, contract_address, collateral_amount);
            IOtokenDispatcher{contract_address: instrument.option_token}.mint(caller, option_token_amount);
            IOtokenDispatcher{contract_address: instrument.writer_token}.mint(caller, writer_token_amount);
            self._increase_pool_balance(collateral_asset, collateral_amount);
            self.emit(Event::option_minted(option_minted { 
                user: caller,
                instrument: instrument,
                collateral_asset: collateral_asset,
                collateral_amount: collateral_amount,
                option_token_amount: option_token_amount,
                writer_token_amount: writer_token_amount,
            }));
            ReentrancyGuard::InternalImpl::end(ref unsafe_state);
        }


        fn close_position(ref self: ContractState, option_token: ContractAddress, option_token_amount: u256){
            self.assert_not_paused();
            let mut unsafe_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref unsafe_state);

            let contract_address = get_contract_address();
            let caller = get_caller_address();
            let instrument = self._get_instrument_by_otoken(option_token);
            let (collateral_asset, collateral_amount) = get_fully_collateralized_margin(option_token_amount, instrument);
            let writer_token_amount = get_writer_token_amount(option_token_amount, instrument);
            IOtokenDispatcher{contract_address: instrument.option_token}.burn(caller, option_token_amount);
            IOtokenDispatcher{contract_address: instrument.writer_token}.burn(caller, writer_token_amount);
            IERC20Dispatcher{contract_address: collateral_asset}.transfer(caller, collateral_amount);
            self._decrease_pool_balance(collateral_asset, collateral_amount);
            self.emit(Event::position_closed(position_closed { 
                user: caller,
                instrument: instrument,
                collateral_asset: collateral_asset,
                collateral_amount: collateral_amount,
                option_token_amount: option_token_amount,
                writer_token_amount: writer_token_amount,
            }));
            ReentrancyGuard::InternalImpl::end(ref unsafe_state);
        }


        fn settle(ref self: ContractState, writer_token: ContractAddress, writer_token_amount: u256){
            self.assert_not_paused();
            let mut unsafe_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref unsafe_state);
            let contract_address = get_contract_address();
            let caller = get_caller_address();
            let instrument = self._get_instrument_by_otoken(writer_token);

            let oracle = self.oracle.read();
            let  (price, settle_enabled) = IOracleDispatcher{contract_address:oracle}.get_expiry_price(instrument.underlying_asset, instrument.expiry_timestamp);
            assert(settle_enabled == true, 'settle is not allowed');
            let (collateral_asset, collateral_amount, is_exercised)= get_expired_cash_value(writer_token_amount, instrument, price);
            IOtokenDispatcher{contract_address: instrument.writer_token}.burn(caller, writer_token_amount);
            IERC20Dispatcher{contract_address: collateral_asset}.transfer(caller, collateral_amount);
            self._decrease_pool_balance(collateral_asset, collateral_amount);
            self.emit(Event::settled(settled { 
                user: caller,
                instrument: instrument,
                collateral_asset: collateral_asset,
                collateral_amount: collateral_amount,
                is_exercised: is_exercised,
                writer_token_amount: writer_token_amount,
            }));
            ReentrancyGuard::InternalImpl::end(ref unsafe_state);
        }

        fn exercise(ref self: ContractState, option_token: ContractAddress, option_token_amount: u256){
            self.assert_not_paused();
            let mut unsafe_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref unsafe_state);
            let contract_address = get_contract_address();
            let caller = get_caller_address();
            let instrument = self._get_instrument_by_otoken(option_token);

            let oracle = self.oracle.read();
            let  (price, settle_enabled) = IOracleDispatcher{contract_address:oracle}.get_expiry_price(instrument.underlying_asset, instrument.expiry_timestamp);
            assert(settle_enabled == true, 'settle is not allowed');
            assert(option_token_amount > 0, 'otoken amount must > 0');

            let (profit_asset, profit_amount, is_exercised) = get_expired_otoken_profit(
                option_token_amount, instrument, price
            );

            IOtokenDispatcher{contract_address: instrument.option_token}.burn(caller, option_token_amount);
            if is_exercised {
                IERC20Dispatcher{contract_address: profit_asset}.transfer(caller, profit_amount);
                self._decrease_pool_balance(profit_asset, profit_amount);
            }
            self.emit(Event::exercised(exercised { 
                user: caller,
                instrument: instrument,
                profit_asset: profit_asset,
                profit_amount: profit_amount,
                is_exercised: is_exercised,
                option_token_amount: option_token_amount,
            }));
            ReentrancyGuard::InternalImpl::end(ref unsafe_state);
        }
    }

    ///
    /// Internals
    ///
    #[generate_trait]
    impl InternalMethods of InternalMethodsTrait { 

        fn assert_not_paused(self: @ContractState) {
            let paused: bool  = self.is_paused.read();
            assert(paused == false, 'system is paused');
        }

        fn assert_only_owner(self: @ContractState) {
            let owner: ContractAddress = self.owner.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), 'Caller is the zero address');
            assert(caller == owner, 'Caller is not the owner');
        }
        fn ownable_initializer(ref self: ContractState, owner: ContractAddress) {
            self._transfer_ownership(owner);
        }
        fn _transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let previous_owner: ContractAddress = self.owner.read();
            self.owner.write(new_owner);
            self.emit(Event::OwnershipTransferred(OwnershipTransferred { previous_owner: previous_owner, new_owner: new_owner }));
        }


        fn _get_instrument_name(
            self: @ContractState,
            _underlying_asset: ContractAddress,
            _quote_asset: ContractAddress,
            _strike_price: u256,
            _expiry_timestamp: felt252,
            _option_type: felt252,
        ) -> felt252 {

            let underlying_symbol = IERC20Dispatcher { contract_address: _underlying_asset }.symbol();
            let quote_symbol = IERC20Dispatcher { contract_address: _quote_asset }.symbol();

            let (year, month, day) = timestamp_to_date(_expiry_timestamp.into());
            let _strike_price_integer = convert_with_decimals(_strike_price, 8, 0);
            let strike_price_felt = felt_to_string(_strike_price_integer);

            let mut name: felt252 = unsafe_literal_concat(underlying_symbol, UNDERSCORE_STRING);
            name = unsafe_literal_concat(name, strike_price_felt);
            name = unsafe_literal_concat(name, _option_type);
            name = unsafe_literal_concat(name, UNDERSCORE_STRING);
            name = unsafe_literal_concat(name, quote_symbol);
            name = unsafe_literal_concat(name, UNDERSCORE_STRING);
            name = unsafe_literal_concat(name, day);
            name = unsafe_literal_concat(name, UNDERSCORE_STRING);
            name = unsafe_literal_concat(name, month);
            name = unsafe_literal_concat(name, UNDERSCORE_STRING);
            name = unsafe_literal_concat(name, year);
            return name;
        }


        fn _get_instrument_by_otoken(self: @ContractState, option_token: ContractAddress) -> Instrument{
            self.otoken_to_instrument.read(option_token)
        }


        fn get_otoken_deploy_calldata(
            self: @ContractState,
            _underlying_asset: ContractAddress,
            _quote_asset: ContractAddress,
            _strike_price: u256,
            _expiry: felt252,
            _option_type: felt252,
            _token_type: felt252,
        ) -> Array<felt252> {
            let mut calldata: Array<felt252> = ArrayTrait::new();
            let contract_address = get_contract_address();
            calldata.append(contract_address_to_felt252(contract_address));
            calldata.append(contract_address_to_felt252(_underlying_asset));
            calldata.append(contract_address_to_felt252(_quote_asset));
            calldata.append(_strike_price.low.into());
            calldata.append(_strike_price.high.into());
            calldata.append(_expiry);
            calldata.append(_option_type);
            calldata.append(_token_type);
            return calldata;
        }

        fn _increase_pool_balance(ref self: ContractState, asset: ContractAddress, amount: u256) {
            assert(!asset.is_zero(),  'asset is zero');
            self.pool_balance.write(asset, self.pool_balance.read(asset) + amount);
        }

        fn _decrease_pool_balance(ref self: ContractState, asset: ContractAddress, amount: u256) {
            assert(!asset.is_zero(),  'asset is zero');
            self.pool_balance.write(asset, self.pool_balance.read(asset) - amount);
        }
    }
}