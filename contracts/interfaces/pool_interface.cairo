%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IPool {
    func deposit(asset :felt, user: felt, amount: Uint256){
    }
    func withdraw(asset :felt, user: felt, amount: Uint256){
    }
}
