%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_block_timestamp

const btc_usd_id = 18669995996566340;
const eth_usd_id = 19514442401534788;

// view
@view
func get_spot_median{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(pair_id: felt) -> (
    price: felt, decimals: felt, last_updated_timestamp: felt, num_sources_aggregated: felt
) {
    let (block_timestamp) = get_block_timestamp();
    if (pair_id == eth_usd_id) {
        return (2500, 8, block_timestamp, 3);
    } 
    return (25000, 8, block_timestamp, 3);
}