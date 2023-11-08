use starknet::{ContractAddress, ClassHash};
use optiondance::libraries::types::{Instrument};

#[starknet::interface]
trait IControllerV2<TContractState> {
    fn get_oracle_v2(self: @TContractState) -> ContractAddress;
    fn owner(self: @TContractState) -> ContractAddress;
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn set_oracle(ref self: TContractState, oracle: ContractAddress);
}


#[starknet::contract]
mod ControllerV2 {
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use starknet::{ContractAddress, get_caller_address, replace_class_syscall, ClassHash};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        oracle: ContractAddress,
    }

    //***********************************************************//
    //                      event
    //***********************************************************//
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        oracle_updated: oracle_updated,
        OwnershipTransferred: OwnershipTransferred,
    }

    #[derive(Drop, starknet::Event)]
    struct oracle_updated {
        oracle: ContractAddress
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
    fn constructor(ref self: ContractState, _oracle: ContractAddress) {
        self.oracle.write(_oracle);
        let caller = get_caller_address();
        self.ownable_initializer();
    }

    #[external(v0)]
    impl ControllerV2 of super::IControllerV2<ContractState> {
        //***********************************************************//
        //                      View
        //***********************************************************//
        fn get_oracle_v2(self: @ContractState) -> ContractAddress {
            self.oracle.read()
        }


        //***********************************************************//
        //                      Access
        //***********************************************************//
        fn owner(self: @ContractState) -> ContractAddress {
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

        fn set_oracle(ref self: ContractState, oracle: ContractAddress) {
            self.assert_only_owner();
            self.oracle.write(oracle);
            self.emit(Event::oracle_updated(oracle_updated { oracle: oracle }));
        }
    }

    ///
    /// Internals
    ///
    #[generate_trait]
    impl InternalMethods of InternalMethodsTrait {
        fn assert_only_owner(self: @ContractState) {
            let owner: ContractAddress = self.owner.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), 'Caller is the zero address');
            assert(caller == owner, 'Caller is not the owner');
        }
        fn ownable_initializer(ref self: ContractState) {
            let caller: ContractAddress = get_caller_address();
            self._transfer_ownership(caller);
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
