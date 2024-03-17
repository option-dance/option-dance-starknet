use core::traits::TryInto;
use core::traits::Into;
use starknet::{ContractAddress, ClassHash};


//
// Message Config
//
const STARKNET_MESSAGE_PREFIX :felt252 = 'StarkNet Message';
const DOMAIN_NAME : felt252 = 'Option Dance';
const APP_VERSION :felt252 = 1;
const STARKNET_DOMAIN_TYPE_HASH :felt252 = 0x98d1932052fc5137543de5ed85b7a88555a4cd1ff5d5bfedb62ed9b9a1f0db;
const ORDER_TYPE_HASH :felt252 = 0x1b801a20e1f41f77266c93f25e6d9cae5262181bc6d4aec248866fb2a71bfbc;
const PRICE_TYPE_HASH :felt252 = 0x1fe7f2a33d0248cd65cc2817d17660a0a4d2978dcedc06d0493258eb7f2ef46;

//
// Order Config
//
const BUY_SIDE: felt252 = 0;
const SELL_SIDE: felt252 = 1;

#[derive(Drop, Copy, Serde)]
struct StarkNetDomain {
    name: felt252,
    version: felt252,
    chain_id: felt252,
}

#[derive(Drop, Copy, Serde)]
struct PriceRatio {
    numerator: u128,
    denominator: u128,
}

#[derive(Drop, Copy, Serde)]
struct Order {
    base_asset: ContractAddress,
    quote_asset: ContractAddress,
    side: felt252,  // 0 = buy, 1 = sell
    base_quantity: u128,
    price: PriceRatio,
    expiration: u64,
    salt: felt252,
}


#[derive(Drop, Copy, Serde)]
struct Message {
    message_prefix: felt252,
    domain_prefix: StarkNetDomain,
    sender: ContractAddress,
    order: Order,
    sig_r: felt252,
    sig_s: felt252,
}



#[starknet::interface]
trait IExchange<TContractState> {
    fn fill_order(ref self: TContractState, buy_order: Message,  sell_order: Message, fill_price: PriceRatio, base_fill_quantity: u128);
    fn cancel_order(ref self: TContractState, order: Message);

    fn get_order_filled_amount(self: @TContractState, orderhash: felt252)-> u128;
    
    fn set_chain_id(ref self: TContractState, chain_id: felt252);
    fn get_chain_id(self: @TContractState) -> felt252;

    fn owner(self: @TContractState) -> ContractAddress;
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
}


#[starknet::contract]
mod Exchange {
    use super::{Message, Order, PriceRatio, StarkNetDomain,
        STARKNET_DOMAIN_TYPE_HASH, STARKNET_MESSAGE_PREFIX, ORDER_TYPE_HASH, PRICE_TYPE_HASH, BUY_SIDE, SELL_SIDE, DOMAIN_NAME, APP_VERSION };
    use optiondance::libraries::hash::{compute_hash_on_elements};
    use optiondance::libraries::account::{IAccount, IAccountDispatcher, IAccountDispatcherTrait};
    use optiondance::libraries::math::{u128_div_rem};
    use optiondance::libraries::erc20::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use optiondance::libraries::reentrancyguard::ReentrancyGuard;
    use array::{ArrayTrait};
    use traits::TryInto;
    use traits::Into;
    use option::OptionTrait;
    use zeroable::Zeroable;
    use starknet::{ContractAddress, ClassHash, get_caller_address, contract_address_to_felt252, get_block_timestamp, replace_class_syscall, VALIDATED};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        order_filled_amount: LegacyMap<felt252, u128>,
        chain_id: felt252
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred,
    }
    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress, 
        new_owner: ContractAddress, 
    }

    #[constructor]
    fn constructor(ref self: ContractState, _owner: ContractAddress, _chain_id: felt252) {
        self.chain_id.write(_chain_id);
        self.ownable_initializer(_owner);
    }



    #[external(v0)]
    impl Exchange of super::IExchange<ContractState> {

        fn fill_order(ref self: ContractState, buy_order: Message,  sell_order: Message, fill_price: PriceRatio, base_fill_quantity: u128){
            let mut unsafe_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref unsafe_state);
            // validate message prefixes
            self.validate_message_prefix(buy_order);
            self.validate_message_prefix(sell_order);

            // validate order
            let buymessagehash = self.compute_message_hash(buy_order);
            let sellmessagehash = self.compute_message_hash(sell_order);
            let filledbuy = self.order_filled_amount.read(buymessagehash);
            let filledsell = self.order_filled_amount.read(sellmessagehash);

            let check_result = self.check_order_valid(buy_order.order, sell_order.order, filledbuy, filledsell, base_fill_quantity, fill_price);
            assert(check_result == true, 'Invalid order');

            // validate signature
            let check_buy_sig = self.verify_message_signature(buy_order);
            let check_sell_sig = self.verify_message_signature(sell_order);

            assert (check_buy_sig , 'invalid message signature');
            assert (check_sell_sig , 'invalid message signature');

            let fulfilled = self.execute_trade(
                base_fill_quantity,
                fill_price,
                buy_order.order.base_asset,
                buy_order.order.quote_asset,
                buy_order.sender,
                sell_order.sender,
            );
            assert( fulfilled == true, 'not fulfilled');

            self.order_filled_amount.write(buymessagehash, filledbuy + base_fill_quantity);
            self.order_filled_amount.write(sellmessagehash, filledsell + base_fill_quantity);
            ReentrancyGuard::InternalImpl::end(ref unsafe_state);
        }

        // Cancels an order by setting the fill quantity to greater than the order size
        fn cancel_order(ref self: ContractState, order: Message){
            let caller = get_caller_address();
            assert(caller == order.sender, 'invalid caller');
            let orderhash = self.compute_message_hash(order); 
            self.order_filled_amount.write(orderhash, order.order.base_quantity + 1);
        }

        // Returns an order status (filled amount)
        fn get_order_filled_amount(self: @ContractState, orderhash: felt252)-> u128{
            self.order_filled_amount.read(orderhash)
        }

        fn set_chain_id(ref self: ContractState, chain_id: felt252){
            self.assert_only_owner();
            self.chain_id.write(chain_id);
        }

        fn get_chain_id(self: @ContractState) -> felt252{
            self.chain_id.read()
        }

        fn owner(self: @ContractState) -> ContractAddress{
            self.owner.read()
        }
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.assert_only_owner();
            replace_class_syscall(new_class_hash);
        }
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            assert(!new_owner.is_zero(), 'New owner is the zero address');
            self.assert_only_owner();
            self._transfer_ownership(new_owner);
        }
    }




    /// Internals
    #[generate_trait]
    impl InternalMethods of InternalMethodsTrait {
        fn validate_message_prefix(self: @ContractState, message: Message) {
            assert(message.message_prefix == STARKNET_MESSAGE_PREFIX, 'wrong message_prefix');
            assert(message.domain_prefix.name == DOMAIN_NAME, 'wrong domain_prefix name');
            assert(message.domain_prefix.version == APP_VERSION, 'wrong domain_prefix version');
            let chain_id = self.chain_id.read();
            assert(message.domain_prefix.chain_id == chain_id, 'wrong domain_prefix chain_id');
        }


        fn compute_message_hash(self: @ContractState, message: Message) -> felt252 {
            let message_prefix = message.message_prefix;

            let domain = message.domain_prefix;
            let mut domain_fields: Array<felt252> = ArrayTrait::new();
            domain_fields.append(STARKNET_DOMAIN_TYPE_HASH);
            domain_fields.append(domain.name);
            domain_fields.append(domain.chain_id);
            domain_fields.append(domain.version);
            let domain_hash = compute_hash_on_elements(domain_fields);

            let sender = message.sender;

            let order = message.order;
            let price = order.price;
            let mut price_fields: Array<felt252> = ArrayTrait::new();
            price_fields.append(PRICE_TYPE_HASH);
            price_fields.append(price.numerator.into());
            price_fields.append(price.denominator.into());
            let price_hash = compute_hash_on_elements(price_fields);

            let mut order_fields: Array<felt252> = ArrayTrait::new();
            order_fields.append(ORDER_TYPE_HASH);
            order_fields.append(contract_address_to_felt252(order.base_asset));
            order_fields.append(contract_address_to_felt252(order.quote_asset));
            order_fields.append(order.side);
            order_fields.append(order.base_quantity.into());
            order_fields.append(price_hash);
            order_fields.append(order.expiration.into());
            order_fields.append(order.salt);
            let order_field_hash = compute_hash_on_elements(order_fields);

            let mut fields  : Array<felt252> = ArrayTrait::new();
            fields.append(message_prefix);
            fields.append(domain_hash);
            fields.append(contract_address_to_felt252(sender));
            fields.append(order_field_hash);
            return compute_hash_on_elements(fields);
        }

        fn check_order_valid(
            self: @ContractState, 
            buy_order: Order,
            sell_order: Order,
            filledbuy: u128,
            filledsell: u128,
            base_fill_quantity: u128,
            fill_price: PriceRatio,
        ) -> bool {
            assert (buy_order.base_asset == sell_order.base_asset, 'Invalid Order:1');
            assert (buy_order.quote_asset == sell_order.quote_asset, 'Invalid Order:2');
            assert( buy_order.side == BUY_SIDE, 'Invalid Order:3');
            assert( sell_order.side == SELL_SIDE, 'Invalid Order:4');
            assert(filledbuy >= 0, 'Invalid Order:5');
            assert(filledsell >= 0, 'Invalid Order:6');
            assert(buy_order.base_quantity >= 0, 'Invalid Order:7');
            assert(sell_order.base_quantity >= 0, 'Invalid Order:8');
            assert(base_fill_quantity >= 0, 'Invalid Order:9');
            assert(filledbuy + base_fill_quantity <= buy_order.base_quantity, 'Invalid Order:10');
            assert(filledsell + base_fill_quantity <= sell_order.base_quantity, 'Invalid Order:11');
            assert(fill_price.numerator * buy_order.price.denominator <= buy_order.price.numerator * fill_price.denominator, 'Invalid Order:12');
            assert(sell_order.price.numerator * fill_price.denominator <= fill_price.numerator * sell_order.price.denominator, 'Invalid Order:13');
            assert(base_fill_quantity <= buy_order.base_quantity, 'Invalid Order:14');
            assert(base_fill_quantity <= sell_order.base_quantity, 'Invalid Order:15');
            let block_timestamp = get_block_timestamp();
            assert(block_timestamp < buy_order.expiration, 'order expired');
            assert(block_timestamp < buy_order.expiration, 'order expired');
            return true;
        }



        fn verify_message_signature(
            self: @ContractState, 
            message: Message,
        ) -> bool {
            let message_hash = self.compute_message_hash(message);
            let mut signature = ArrayTrait::new();
            signature.append(message.sig_r);
            signature.append(message.sig_s);
            let is_valid = IAccountDispatcher{contract_address: message.sender}.is_valid_signature(
                message_hash, signature
            );
            let mut valid_flag = 0;
            // compatible with argentx
            if  is_valid == VALIDATED {
                valid_flag = valid_flag + 1;
            }
            // compatible with braavos
            if  is_valid == 1 {
                valid_flag = valid_flag + 1;
            }
            assert(valid_flag == 1, 'Should accept valid signature');
            return true;
        }


        fn execute_trade(
            ref self: ContractState, 
            base_fill_quantity: u128,
            fill_price: PriceRatio,
            base_asset: ContractAddress,
            quote_asset: ContractAddress,
            buyer: ContractAddress,
            seller: ContractAddress,
        ) -> bool {
            let (quote_fill_quantity, _) = u128_div_rem(base_fill_quantity * fill_price.numerator, fill_price.denominator);
            IERC20Dispatcher{contract_address: base_asset}.transfer_from(seller, buyer, base_fill_quantity.into());
            IERC20Dispatcher{contract_address: quote_asset}.transfer_from(buyer, seller, quote_fill_quantity.into());
            return true;
        }


        fn assert_only_owner(self: @ContractState) {
            let owner: ContractAddress = self.owner.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), 'Caller is the zero address');
            assert(caller == owner, 'Caller is not the owner');
        }
        fn ownable_initializer(ref self: ContractState, owner: ContractAddress) {
            self._transfer_ownership(owner);
        }
        fn _transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let previous_owner: ContractAddress = self.owner.read();
            self.owner.write(new_owner);
            self.emit(Event::OwnershipTransferred(OwnershipTransferred { previous_owner: previous_owner, new_owner: new_owner }));
        }
    }
}