%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IOracle {
    func get_expiry_price(asset: felt, expiry_timestamp: felt) -> (
        price: Uint256, settle_enabled: felt
    ) {
    }

    func owner() -> (owner: felt) {
    }

    func get_price_syncer() -> (price_syncer: felt) {
    }

    func get_dispute_time() -> (dispute_time: felt) {
    }

    func set_dispute_time(dispute_time: felt) {
    }

    func set_price_syncer(price_syncer: felt) {
    }

    func set_expiry_price(asset: felt, expiry_timestamp: felt, expiry_price: Uint256) {
    }
}
