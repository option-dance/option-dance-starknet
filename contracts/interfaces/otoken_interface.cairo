%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IOtoken {
    //
    // views
    //
    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func decimals() -> (decimals: felt) {
    }

    func totalSupply() -> (totalSupply: Uint256) {
    }

    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256) {
    }

    func underlying_asset() -> (underlying_asset: felt) {
    }

    func quote_asset() -> (quote_asset: felt) {
    }
    func strike_price() -> (strike_price: Uint256) {
    }
    func option_type() -> (option_type: felt) {
    }
    func token_type() -> (token_type: felt) {
    }
    func expiry_timestamp() -> (expiry_timestamp: Uint256) {
    }
    func option_id() -> (option_id: felt) {
    }

    //
    // external
    //
    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }

    func increaseAllowance(spender: felt, added_value: Uint256) -> (success: felt) {
    }

    func decreaseAllowance(spender: felt, subtracted_value: Uint256) -> (success: felt) {
    }

    func mint(to: felt, amount: Uint256) {
    }

    func burn(account: felt, amount: Uint256) {
    }

    func set_option_id(option_id: felt) {
    }

    func transferOwnership(newOwner: felt) {
    }
    func renounceOwnership() {
    }
}
