#[allow(unused_variable)]
/// Module: orderbook
module orderbook::orderbook {
    use orderbook::bp_tree::{Self, BPTree};
    use sui::object::UID;

    public struct Order {
        id: u64,
        price: u64,
        quantity: u64,
    }

    public struct OrderBook {
        orders: vector<Order>,
    }

    public fun add_to_post_receipt(is_ask: bool, size: u64) {
        // TODO: Implement function
    }

    public fun best_price(orderbook: &OrderBook, is_ask: bool): option::Option<u64> {
        // TODO: Implement function
    }

    public fun book_price(orderbook: &OrderBook): option::Option<u64> {
        // TODO: Implement function
    }

    public fun cancel_limit_order(orderbook: &mut OrderBook, account_id: address, order_id: u64): u64 {
        // TODO: Implement function
    }

    public fun change_BPTrees_params(orderbook: &mut OrderBook, max_depth: u64, max_key: u64, max_value: u64, max_size: u64, max_load_factor: u64, max_load_factor_hard_limit: u64) {
        // TODO: Implement function
    }

    public fun create_empty_post_receipt(): PostReceipt {
        // TODO: Implement function
    }

    public fun create_orderbook(max_depth: u64, max_key: u64, max_value: u64, max_size: u64, max_load_factor: u64, max_load_factor_hard_limit: u64, ctx: &mut TxContext): OrderBook {
        // TODO: Implement function
    }

    public fun fill_limit_order(orderbook: &mut OrderBook, account_id: address, is_ask: bool, size: u64, price: u64, order_type: u64, fill_receipts: &mut vector<FillReceipt>): u64 {
        // TODO: Implement function
    }

    public fun fill_market_order(orderbook: &mut OrderBook, account_id: address, is_ask: bool, size: u64, fill_receipts: &mut vector<FillReceipt>): u64 {
        // TODO: Implement function
    }

    public fun get_asks(orderbook: &OrderBook): &BPTree<u64, Order> {
        // TODO: Implement function
    }

    public fun get_bids(orderbook: &OrderBook): &BPTree<u64, Order> {
        // TODO: Implement function
    }

    public fun get_asks_mut(orderbook: &mut OrderBook): &mut BPTree<u64, Order> {
        // TODO: Implement function
    }

    public fun get_bids_mut(orderbook: &mut OrderBook): &mut BPTree<u64, Order> {
        // TODO: Implement function
    }

    public fun get_fill_receipt_info(receipt: &FillReceipt): (address, u64, u64, u64) {
        // TODO: Implement function
    }

    public fun get_order_size(orderbook: &OrderBook, order_id: u64): u64 {
        // TODO: Implement function
    }

    public fun get_post_receipt_info(receipt: &PostReceipt): (u64, u64, u64) {
        // TODO: Implement function
    }

    public fun increase_counter(counter: &mut u64): u64 {
        // TODO: Implement function
    }

    public fun migrate_to_left_branch(BPTree: &mut BPTree<u64, Order>, branch_id: u64, remaining_size: u64, split_key: u64, first_kid: u64) -> u64 {
        // TODO: Implement function
    }

    public fun migrate_to_left_leaf(BPTree: &mut BPTree<u64, Order>, leaf_id: u64, remaining_size: u64, first_kid: u64) -> u64 {
        // TODO: Implement function
    }

    public fun place_limit_order(orderbook: &mut OrderBook, account_id: address, is_ask: bool, size: u64, price: u64, order_type: u64, fill_receipts: &mut vector<FillReceipt>, post_receipt: &mut PostReceipt, market_id: &address): u64 {
        // TODO: Implement function
    }

    public fun place_market_order(orderbook: &mut OrderBook, account_id: address, is_ask: bool, size: u64, fill_receipts: &mut vector<FillReceipt>) {
        // TODO: Implement function
    }

    public fun post_order(orderbook: &mut OrderBook, account_id: address, is_ask: bool, size: u64, price: u64, post_receipt: &mut PostReceipt, market_id: &address) {
        // TODO: Implement function
    }
}
