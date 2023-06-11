%lang starknet

from starkware.cairo.common.uint256 import Uint256

struct Instrument {
    id: felt,
    name: felt,
    option_token: felt,
    writer_token: felt,
    underlying_asset: felt,
    quote_asset: felt,
    strike_price: Uint256,
    expiry_timestamp: felt,
    option_type: felt,
}

struct ExpiryPrice {
    price: Uint256,
    timestamp: felt,
}
