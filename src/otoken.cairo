use starknet::ContractAddress;

#[starknet::interface]
trait IOtoken<TContractState> {
    fn owner(self: @TContractState) -> ContractAddress;
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn totalSupply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn underlying_asset(self: @TContractState) -> ContractAddress;
    fn quote_asset(self: @TContractState) -> ContractAddress;
    fn strike_price(self: @TContractState) -> u256;
    fn option_type(self: @TContractState) -> felt252;
    fn token_type(self: @TContractState) -> felt252;
    fn expiry_timestamp(self: @TContractState) -> felt252;
    fn option_id(self: @TContractState) -> felt252;
    fn option_name(self: @TContractState) -> felt252;
    fn get_otoken_name(
        self: @TContractState,
        _underlying_asset: ContractAddress,
        _quote_asset: ContractAddress,
        _strike_price: u256,
        _expiry_timestamp: felt252,
        _option_type: felt252,
        _token_type: felt252,
    ) ->  felt252;


    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: u256) -> bool;
    fn decrease_allowance(ref self: TContractState, spender: ContractAddress, subtracted_value: u256) -> bool;
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, account: ContractAddress, amount: u256);
    fn set_option_id(ref self: TContractState, option_id: felt252);
    fn set_option_name(ref self: TContractState, option_name: felt252);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
}


#[starknet::contract]
mod Otoken {
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;
    use integer::BoundedInt;
    use super::IOtoken;
    use starknet::{ContractAddress,get_caller_address,get_block_timestamp,contract_address_to_felt252 };
    use zeroable::Zeroable;
    use optiondance::libraries::erc20::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use optiondance::libraries::time::{timestamp_to_date};
    use optiondance::libraries::math::{u256_pow, u256_div_rem, mul_with_decimals, convert_with_decimals, u256_to_felt};
    use optiondance::libraries::string::{felt_to_string, unsafe_literal_concat};
    use optiondance::libraries::constant::{UNDERSCORE_STRING,
     TOKEN_TYPE_OPTION, TOKEN_TYPE_WRITER, OPTION_TYPE_PUT, OPTION_TYPE_CALL, OTOKEN_DECIMALS};

    #[storage]
    struct Storage {
        _owner: ContractAddress,
        _name: felt252,
        _symbol: felt252,
        _decimals: u8,
        _total_supply: u256,
        _balances: LegacyMap<ContractAddress, u256>,
        _allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
        otoken_underlying_asset: ContractAddress,
        otoken_quote_asset: ContractAddress,
        otoken_strike_price: u256,
        otoken_expiry_timestamp: felt252,
        otoken_option_type: felt252,
        otoken_token_type: felt252,
        otoken_option_id: felt252,
        otoken_option_name: felt252
    }




    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        OwnershipTransferred: OwnershipTransferred,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress, 
        to: ContractAddress, 
        value: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress, 
        spender: ContractAddress, 
        value: u256
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress, 
        new_owner: ContractAddress, 
    }


    #[external(v0)]
    impl Otoken of super::IOtoken<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress{
            self._owner.read()
        }
        fn name(self: @ContractState) -> felt252{
            self._name.read()
        }
        fn symbol(self: @ContractState) -> felt252{
            self._symbol.read()
        }
        fn decimals(self: @ContractState) -> u8{
            self._decimals.read()
        }
        fn total_supply(self: @ContractState) -> u256{
            self._total_supply.read()
        }
        fn totalSupply(self: @ContractState) -> u256{
            self._total_supply.read()
        }        
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256{
             self._balances.read(account)
        }
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256{
             self._balances.read(account)
        }
        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256{
            self._allowances.read((owner, spender))
        }
        fn underlying_asset(self: @ContractState) -> ContractAddress{
            self.otoken_underlying_asset.read()
        }
        fn quote_asset(self: @ContractState) -> ContractAddress{
            self.otoken_quote_asset.read()
        }
        fn strike_price(self: @ContractState) -> u256{
            self.otoken_strike_price.read()
        }
        fn option_type(self: @ContractState) -> felt252{
            self.otoken_option_type.read()
        }
        fn token_type(self: @ContractState) -> felt252{
            self.otoken_token_type.read()
        }
        fn expiry_timestamp(self: @ContractState) -> felt252{
            self.otoken_expiry_timestamp.read()
        }
        fn option_id(self: @ContractState) -> felt252{
            self.otoken_option_id.read()
        }
        fn option_name(self: @ContractState) -> felt252{
            self.otoken_option_name.read()
        }
        fn get_otoken_name(
            self: @ContractState,
            _underlying_asset: ContractAddress,
            _quote_asset: ContractAddress,
            _strike_price: u256,
            _expiry_timestamp: felt252,
            _option_type: felt252,
            _token_type: felt252,
        ) ->  felt252 {

            let underlying_symbol = IERC20Dispatcher { contract_address: _underlying_asset }.symbol();
            let quote_symbol = IERC20Dispatcher { contract_address: _quote_asset }.symbol();

            let (year, month, day) = timestamp_to_date(_expiry_timestamp.into());
            

            let _strike_price_integer = convert_with_decimals(_strike_price, 8, 0);
            let strike_price_felt = felt_to_string(_strike_price_integer);
            // let strike_price_felt = 49;
            
            let mut name: felt252 = unsafe_literal_concat(_token_type, underlying_symbol);
            name = unsafe_literal_concat(name, UNDERSCORE_STRING);
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






        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool{
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }
        fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool{
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }
        fn transferFrom(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool{
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool{
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }
        fn increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u256) -> bool{
            self._increase_allowance(spender, added_value)
        }
        fn decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u256) -> bool{
            self._decrease_allowance(spender, subtracted_value)
        }
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256){
            self.assert_only_owner();
            self._mint(recipient, amount);
        }
        fn burn(ref self: ContractState, account: ContractAddress, amount: u256){
            self.assert_only_owner();
            self._burn(account, amount);
        }
        fn set_option_id(ref self: ContractState, option_id: felt252){
            self.assert_only_owner();
            self.otoken_option_id.write(option_id);
        }
        fn set_option_name(ref self: ContractState, option_name: felt252){
            self.assert_only_owner();
            self.otoken_option_name.write(option_name);
        }
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress){
            assert(!new_owner.is_zero(), 'New owner is the zero address');
            self.assert_only_owner();
            self._transfer_ownership(new_owner);
        }
   }



    #[constructor]
    fn constructor(
        ref self: ContractState,
        _owner: ContractAddress,
        _underlying_asset: ContractAddress,
        _quote_asset: ContractAddress,
        _strike_price: u256,
        _expiry_timestamp: felt252,
        _option_type: felt252,
        _token_type: felt252,
    ) {
        // check expiry timestamp and strike price
        let block_timestamp = get_block_timestamp();

        let expiry_timestamp:u64 = _expiry_timestamp.try_into().unwrap();
        assert(block_timestamp < expiry_timestamp, 'invalid expiry timestamp');
        let strike_price_felt = u256_to_felt(_strike_price);
        assert(_strike_price > 100000000,  'strike price must > 10^8');

        let name = self.get_otoken_name(
            _underlying_asset,
            _quote_asset,
            _strike_price,
            _expiry_timestamp,
            _option_type,
            _token_type,
        );
        self.initializer(name, name, OTOKEN_DECIMALS);
        self.ownable_initializer(_owner);
        self.otoken_underlying_asset.write(_underlying_asset);
        self.otoken_quote_asset.write(_quote_asset);
        self.otoken_strike_price.write(_strike_price);
        self.otoken_expiry_timestamp.write(_expiry_timestamp);
        self.otoken_option_type.write(_option_type);
        self.otoken_token_type.write(_token_type);
    }







    ///
    /// Internals
    ///
    #[generate_trait]
    impl InternalMethods of InternalMethodsTrait { 
        fn initializer(ref self: ContractState, name_: felt252, symbol_: felt252, decimals_: u8) {
            self._name.write(name_);
            self._symbol.write(symbol_);
            self._decimals.write(decimals_);
        }

        fn ownable_initializer(ref self: ContractState, owner: ContractAddress) {
            self._transfer_ownership(owner);
        }

        fn assert_only_owner(self: @ContractState) {
            let owner: ContractAddress = self._owner.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), 'Caller is the zero address');
            assert(caller == owner, 'Caller is not the owner');
        }


        fn _increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u256) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self._allowances.read((caller, spender)) + added_value);
            true
        }

        fn _decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u256) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self._allowances.read((caller, spender)) - subtracted_value);
            true
        }

        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(!recipient.is_zero(), 'ERC20: mint to 0');
            self._total_supply.write(self._total_supply.read() + amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Event::Transfer(Transfer { from: Zeroable::zero(), to: recipient, value: amount }));

        }

        fn _burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            assert(!account.is_zero(), 'ERC20: burn from 0');
            self._total_supply.write(self._total_supply.read() - amount);
            self._balances.write(account, self._balances.read(account) - amount);
            self.emit(Event::Transfer(Transfer { from: account, to: Zeroable::zero(), value: amount }));
        }

        fn _approve(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256) {
            assert(!owner.is_zero(), 'ERC20: approve from 0');
            assert(!spender.is_zero(), 'ERC20: approve to 0');
            self._allowances.write((owner, spender), amount);
            self.emit(Event::Approval(Approval {owner: owner, spender: spender, value: amount} ));
        }

        fn _transfer(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) {
            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            self._balances.write(sender, self._balances.read(sender) - amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Event::Transfer(Transfer { from: sender, to: recipient, value: amount }));
        }

        fn _spend_allowance(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256) {
            let current_allowance = self._allowances.read((owner, spender));
            if current_allowance != BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }


        fn renounce_ownership(ref self: ContractState) {
            self.assert_only_owner();
            self._transfer_ownership(Zeroable::zero());
        }

        fn _transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let previous_owner: ContractAddress = self._owner.read();
            self._owner.write(new_owner);
            self.emit(Event::OwnershipTransferred(OwnershipTransferred { previous_owner: previous_owner, new_owner: new_owner }));
        }

    }
}