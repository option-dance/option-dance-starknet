use starknet::{ContractAddress};

#[derive(Copy, Drop, Serde, storage_access::StorageAccess)]
struct Instrument {
    id: felt252,               
    name: felt252,
    option_token: ContractAddress,
    writer_token: ContractAddress,
    underlying_asset: ContractAddress,
    quote_asset: ContractAddress,
    strike_price: u256,
    expiry_timestamp: u64,
    option_type: felt252
}


         
#[derive(Copy, Drop, Serde, storage_access::StorageAccess)]
struct ExpiryPrice {
    price: u256,
    timestamp: u64,
}