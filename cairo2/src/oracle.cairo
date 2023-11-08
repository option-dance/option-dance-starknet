use core::traits::Into;
use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IOracle<TContractState> {
    fn get_expiry_price(self: @TContractState, asset: ContractAddress, expiry_timestamp: u64) -> (u256, bool);
    fn owner(self: @TContractState)-> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn is_price_syncer(self: @TContractState, price_syncer: ContractAddress)-> bool;
    fn get_dispute_time(self: @TContractState)-> u64;

    fn set_dispute_time(ref self: TContractState, dispute_time: u64);
    fn set_price_syncer(ref self: TContractState, price_syncer: ContractAddress, enabled: bool);

    fn set_expiry_price(ref self: TContractState, asset: ContractAddress, expiry_timestamp: u64, expiry_price: u256);
}


#[starknet::contract]
mod Oracle {
    use traits::Into;
    use traits::Default;
    use traits::TryInto;
    use zeroable::Zeroable;
    use optiondance::libraries::types::{ExpiryPrice};
    use starknet::{ContractAddress,ClassHash, get_block_timestamp, get_caller_address, replace_class_syscall};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        oracle_pricer: LegacyMap<ContractAddress, bool>,
        oracle_dispute_time: u64,
        oracle_expiry_price: LegacyMap<(ContractAddress, u64), ExpiryPrice>,
    }



    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        oracle_pricer_updated: oracle_pricer_updated,
        oracle_dispute_time_updated: oracle_dispute_time_updated,
        oracle_expiry_price_updated: oracle_expiry_price_updated,
        OwnershipTransferred: OwnershipTransferred,
    }
    
    #[derive(Drop, starknet::Event)]
    struct oracle_pricer_updated {
        pricer: ContractAddress,
        enabled: bool
    }
    #[derive(Drop, starknet::Event)]
    struct oracle_dispute_time_updated {
        dispute_time: u64,
    }
    #[derive(Drop, starknet::Event)]
    struct oracle_expiry_price_updated {
        pricer: ContractAddress,
        asset: ContractAddress,
        expiry_timestamp: u64,
        expiry_price: ExpiryPrice
    }    
    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress, 
        new_owner: ContractAddress, 
    }


    #[constructor]
    fn constructor(
        ref self: ContractState,
        _owner: ContractAddress,
        _pricer: ContractAddress,
        _dispute_time: u64,
    ) {
        self.ownable_initializer(_owner);
        self.oracle_pricer.write(_pricer, true);
        self.oracle_dispute_time.write(_dispute_time);

        self.emit(Event::oracle_pricer_updated(oracle_pricer_updated { pricer: _pricer, enabled: true }));
        self.emit(Event::oracle_dispute_time_updated(oracle_dispute_time_updated { dispute_time: _dispute_time }));
    }





    #[external(v0)]
    impl Oracle of super::IOracle<ContractState> {
    
        fn get_expiry_price(self: @ContractState, asset: ContractAddress, expiry_timestamp: u64) -> (u256, bool){
            let block_timestamp = get_block_timestamp();
            let _expiry_price = self.oracle_expiry_price.read((asset, expiry_timestamp));
            // check if price timestamp is valid
            if _expiry_price.timestamp == 0 {
                return (_expiry_price.price, false);
            }
            //check if price is valid, should > 10 ^ 6 (0.01)
            let min_price = u256{low:1000000, high:0};
            if _expiry_price.price <= min_price {
                return (_expiry_price.price, false);
            }
            
            let dispute_time = self.oracle_dispute_time.read();
            let dispute_end_at = _expiry_price.timestamp + dispute_time;
            if block_timestamp < dispute_end_at {
                return (_expiry_price.price, false);
            }
            return (_expiry_price.price, true);
        }

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
        fn is_price_syncer(self: @ContractState, price_syncer: ContractAddress)-> bool{
            self.oracle_pricer.read(price_syncer)
        }
        fn get_dispute_time(self: @ContractState)-> u64{
            self.oracle_dispute_time.read()
        }

        fn set_dispute_time(ref self: ContractState, dispute_time: u64){
            self.assert_only_owner();
            self.oracle_dispute_time.write(dispute_time);
        }
        fn set_price_syncer(ref self: ContractState, price_syncer: ContractAddress, enabled: bool){
            self.assert_only_owner();
            self.oracle_pricer.write(price_syncer, enabled);
        }

        fn set_expiry_price(ref self: ContractState, asset: ContractAddress, expiry_timestamp: u64, expiry_price: u256){
            self.assert_only_price_syncer();
            let block_timestamp = get_block_timestamp();
            let caller = get_caller_address();
            assert(block_timestamp >= expiry_timestamp, 'cannot set price before expiry');

            let pre_expiry_price = self.oracle_expiry_price.read((asset, expiry_timestamp));

            // dispute expiry price
            if pre_expiry_price.price > 0 {
                // if expiryPrice is already set
                let dispute_time = self.oracle_dispute_time.read();
                let dispute_end_at = pre_expiry_price.timestamp + dispute_time;
                assert(block_timestamp < dispute_end_at, 'no dispute after dispute time');
                // dispute and update exists expiry price
                self.oracle_expiry_price.write(
                    (asset, expiry_timestamp), ExpiryPrice{price: expiry_price, timestamp: pre_expiry_price.timestamp}
                );
                self.emit(Event::oracle_expiry_price_updated(
                    oracle_expiry_price_updated { 
                        pricer: caller,
                        asset: asset,
                        expiry_timestamp: expiry_timestamp,
                        expiry_price: ExpiryPrice{price: expiry_price, timestamp: pre_expiry_price.timestamp}
                    }
                ));
            }else {
                // if expiryPrice is not set
                self.oracle_expiry_price.write(
                    (asset, expiry_timestamp), ExpiryPrice{price: expiry_price, timestamp: block_timestamp}
                );
                self.emit(Event::oracle_expiry_price_updated(
                    oracle_expiry_price_updated { 
                        pricer: caller,
                        asset: asset,
                        expiry_timestamp: expiry_timestamp,
                        expiry_price: ExpiryPrice{price: expiry_price, timestamp: block_timestamp}
                    }
                ));
            }
        }
    }


    /// Internals
    #[generate_trait]
    impl InternalMethods of InternalMethodsTrait { 
        fn ownable_initializer(ref self: ContractState, owner: ContractAddress) {
            self._transfer_ownership(owner);
        }

        fn assert_only_owner(self: @ContractState) {
            let owner: ContractAddress = self.owner.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), 'Caller is the zero address');
            assert(caller == owner, 'Caller is not the owner');
        }
        fn assert_only_price_syncer(self: @ContractState) {
            let caller = get_caller_address();
            let is_price_syncer = self.oracle_pricer.read(caller);
            assert(is_price_syncer, 'Caller is the price syncer');
        }

        fn _transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let previous_owner: ContractAddress = self.owner.read();
            self.owner.write(new_owner);
            self.emit(Event::OwnershipTransferred(OwnershipTransferred { previous_owner: previous_owner, new_owner: new_owner }));
        }
    }
}