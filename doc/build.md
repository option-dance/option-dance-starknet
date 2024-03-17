# compile contract
```
starknet-compile --contract-path  optiondance::exchange::Exchange   --allowed-libfuncs-list-name all .  abis/exchange.json
starknet-compile --contract-path  optiondance::oracle::Oracle  --allowed-libfuncs-list-name all  .  abis/oracle.json
starknet-compile --contract-path  optiondance::otoken::Otoken  --allowed-libfuncs-list-name all  .  abis/otoken.json
starknet-compile --contract-path  optiondance::libraries::erc20::ERC20   --allowed-libfuncs-list-name all   .  abis/erc20.json
starknet-compile --contract-path   optiondance::controller::Controller  --allowed-libfuncs-list-name all  .  abis/controller.json
starknet-compile --contract-path   optiondance::pragma_pricer::PragmaPricer --allowed-libfuncs-list-name all   .  abis/pragmaPricer.json
starknet-compile --contract-path   optiondance::mocks::mock_erc20::ERC20   --allowed-libfuncs-list-name all   .  abis/mockERC20.json
```

# declare contract classhash
```
starknet declare  --contract abis/controller.json  --account xxx
```

# deploy classhash

```
starknet deploy --class_hash 0x57ba06569f34bdcde912a408496fa8851edc09ba981bd646329e8ae166e71c5 --inputs   x   y  z  --account xxx
```