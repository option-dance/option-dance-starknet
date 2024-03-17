# OptionDance Starknet

OptionDance is a new protocol for users to trade options in simplified strategies abstracting away the complex structuring and sourcing of liquidity behind the scene using smart contracts. Please review our [documentation](https://docs.option.dance) for more details.


## Getting Started

### Compiling

using `starknet-compile`  for compiling contracts, e.g.
```
starknet-compile --contract-path  optiondance::exchange::Exchange   --allowed-libfuncs-list-name all .  abis/exchange.json
starknet-compile --contract-path  optiondance::oracle::Oracle  --allowed-libfuncs-list-name all  .  abis/oracle.json
starknet-compile --contract-path  optiondance::otoken::Otoken  --allowed-libfuncs-list-name all  .  abis/otoken.json
starknet-compile --contract-path  optiondance::libraries::erc20::ERC20   --allowed-libfuncs-list-name all   .  abis/erc20.json
starknet-compile --contract-path   optiondance::controller::Controller  --allowed-libfuncs-list-name all  .  abis/controller.json
starknet-compile --contract-path   optiondance::pragma_pricer::PragmaPricer --allowed-libfuncs-list-name all   .  abis/pragmaPricer.json
starknet-compile --contract-path   optiondance::mocks::mock_erc20::ERC20   --allowed-libfuncs-list-name all   .  abis/mockERC20.json
```

### Running tests
```
scarb test
```