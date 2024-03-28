#[starknet::interface]
trait IMockPragmaOracle<TContractState> {
    fn get_spot_median(
        self: @TContractState, pair_id: felt252
    ) -> (felt252, felt252, felt252, felt252);

    fn set_spot_median(
        ref self: TContractState,
        pair_id: felt252,
        price: felt252,
        decimals: felt252,
        last_updated_timestamp: felt252,
        num_sources_aggregated: felt252
    );
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct PragmaPricesResponse {
    price: felt252,
    decimals: felt252,
    last_updated_timestamp: felt252,
    num_sources_aggregated: felt252,
}


#[starknet::contract]
mod MockPragmaOracle {
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;
    use array::ArrayTrait;
    use super::{
        IMockPragmaOracle, IMockPragmaOracleDispatcher, IMockPragmaOracleDispatcherTrait,
        PragmaPricesResponse
    };


    #[storage]
    struct Storage {
        pair_id_median_price: LegacyMap<felt252, PragmaPricesResponse>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, ) {}

    #[external(v0)]
    impl MockPragmaOracle of IMockPragmaOracle<ContractState> {
        fn get_spot_median(
            self: @ContractState, pair_id: felt252
        ) -> (felt252, felt252, felt252, felt252) {
            let pragmaPricesResponse = self.pair_id_median_price.read(pair_id);
            (
                pragmaPricesResponse.price,
                pragmaPricesResponse.decimals,
                pragmaPricesResponse.last_updated_timestamp,
                pragmaPricesResponse.num_sources_aggregated,
            )
        }

        fn set_spot_median(
            ref self: ContractState,
            pair_id: felt252,
            price: felt252,
            decimals: felt252,
            last_updated_timestamp: felt252,
            num_sources_aggregated: felt252
        ) {
            let pragmaPricesResponse = PragmaPricesResponse {
                price: price,
                decimals: decimals,
                last_updated_timestamp: last_updated_timestamp,
                num_sources_aggregated: num_sources_aggregated
            };
            self.pair_id_median_price.write(pair_id, pragmaPricesResponse);
        }
    }
}
