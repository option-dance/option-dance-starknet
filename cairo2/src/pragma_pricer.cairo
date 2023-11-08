use starknet::{ContractAddress};

#[starknet::interface]
trait IPragmaOracle<TContractState> {
    fn get_spot_median(
        self: @TContractState, pair_id: felt252
    ) -> (felt252, felt252, felt252, felt252);
}


#[starknet::interface]
trait IPragmaPricer<TContractState> {
    fn get_spot_median(
        self: @TContractState, pair_id: felt252
    ) -> (felt252, felt252, felt252, felt252);

    fn get_option_dance_oracle(self: @TContractState) -> ContractAddress;
    fn get_pragma_oracle(self: @TContractState) -> ContractAddress;
    fn set_option_dance_oracle(ref self: TContractState, option_dance_oracle: ContractAddress);
    fn set_pragma_oracle(ref self: TContractState, pragma_oracle: ContractAddress);

    fn owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);

    fn bind_asset_pair_id(ref self: TContractState, asset: ContractAddress, pair_id: felt252);
    fn set_expiry_price_in_oracle(ref self: TContractState, asset: ContractAddress, expiry_timestamp: u64);
}


#[starknet::contract]
mod PragmaPricer {
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use starknet::{ContractAddress, get_caller_address};

    use super::{IPragmaOracle, IPragmaOracleDispatcher, IPragmaOracleDispatcherTrait};
    use optiondance::libraries::math::{convert_with_decimals};
    use optiondance::oracle::{IOracleDispatcher, IOracleDispatcherTrait, Oracle};


    #[storage]
    struct Storage {
        owner: ContractAddress,
        option_dance_oracle: ContractAddress,
        pragma_oracle: ContractAddress,
        asset_pair_id: LegacyMap<ContractAddress, felt252>,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred,
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
    fn constructor(
        ref self: ContractState,
        _owner: ContractAddress,
        _option_dance_oracle: ContractAddress,
        _pragma_oracle: ContractAddress
    ) {
        self.option_dance_oracle.write(_option_dance_oracle);
        self.pragma_oracle.write(_pragma_oracle);
        self.ownable_initializer(_owner);
    }


    #[external(v0)]
    impl PragmaPricer of super::IPragmaPricer<ContractState> {
        fn get_spot_median(
            self: @ContractState, pair_id: felt252
        ) -> (felt252, felt252, felt252, felt252) {
            let pragma_oracle = self.pragma_oracle.read();
            let (price, decimals, last_updated_timestamp, num_sources_aggregated) =
                IPragmaOracleDispatcher {
                contract_address: pragma_oracle
            }.get_spot_median(pair_id);
            (price, decimals, last_updated_timestamp, num_sources_aggregated)
        }

        fn get_option_dance_oracle(self: @ContractState) -> ContractAddress {
            self.option_dance_oracle.read()
        }
        fn get_pragma_oracle(self: @ContractState) -> ContractAddress {
            self.pragma_oracle.read()
        }
        fn set_option_dance_oracle(ref self: ContractState, option_dance_oracle: ContractAddress) {
            self.assert_only_owner();
            self.option_dance_oracle.write(option_dance_oracle);
        }
        fn set_pragma_oracle(ref self: ContractState, pragma_oracle: ContractAddress) {
            self.assert_only_owner();
            self.pragma_oracle.write(pragma_oracle);
        }

        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            assert(!new_owner.is_zero(), 'New owner is the zero address');
            self.assert_only_owner();
            self._transfer_ownership(new_owner);
        }

        fn bind_asset_pair_id(ref self: ContractState, asset: ContractAddress, pair_id: felt252) {
            self.assert_only_owner();
            self.asset_pair_id.write(asset, pair_id);
        }
        fn set_expiry_price_in_oracle(
            ref self: ContractState, asset: ContractAddress, expiry_timestamp: u64
        ) {
            self.assert_only_owner();

            let pair_id = self.asset_pair_id.read(asset);
            let pragma_oracle = self.pragma_oracle.read();
            let option_dance_oracle = self.option_dance_oracle.read();
            //check pair id
            assert(!(pair_id == 0), 'pair_id not found');
            // get pragma spot median price
            let (price, decimals, last_updated_timestamp, num_sources_aggregated) =
                IPragmaOracleDispatcher {
                contract_address: pragma_oracle
            }.get_spot_median(pair_id);

            //check timestamp
            let last_updated_timestamp_u64: u64 = last_updated_timestamp.try_into().unwrap();
            assert(
                last_updated_timestamp_u64 >= expiry_timestamp, 'cannot set price before expiry'
            );
            // set price in option dance oracle
            let expiry_price = convert_with_decimals(price.into(), decimals.try_into().unwrap(), 8);
            IOracleDispatcher {
                contract_address: option_dance_oracle
            }.set_expiry_price(asset, expiry_timestamp, expiry_price);
        }
    }


    //***********************************************************//
    //                      Internal
    //***********************************************************//
    #[generate_trait]
    impl InternalMethods of InternalMethodsTrait {
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
            self
                .emit(
                    Event::OwnershipTransferred(
                        OwnershipTransferred {
                            previous_owner: previous_owner, new_owner: new_owner
                        }
                    )
                );
        }
    }
}
