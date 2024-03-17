#[starknet::interface]
trait IAccount<TContractState> {
    fn is_valid_signature(self: @TContractState,  message: felt252, signature: Array<felt252>) -> felt252;
}