#[allow(unused_variable)]
/// Module: orderbook
module orderbook::orderbook {
    use sui::object::new as new_uid;
    use orderbook::bp_tree::{BPTree, empty as bp_tree_empty, first_leaf_ptr, borrow_leaf, borrow_leaf_mut, borrow_leaf_elem, borrow_leaf_elem_mut, leaf_next, leaf_size, remove};
    //remove(key, val), first_leaf_ptr, borrow_leaf, leaf_next, and update(key, val) need to be implemented in bp_tree

    #[allow(unused_field)]
    public struct Order has store, copy, drop{
        account_id: address,
        price: u64,
        quantity: u64,
    }

    public struct OrderBook {
        id: UID,
        asks: BPTree<Order>,
        bids: BPTree<Order>,
        counter: u64,
    }

    public struct PostReceipt {
        base_ask: u64,
        base_bid: u64,
        pending_orders: u64,
    }

    public struct FillReceipt {
        account_id: address,
        order_id: u128,
        size: u64,
        final_size: u64,
    }

    public fun create_orderbook(branch_order: u64, leaf_order: u64, ctx: &mut TxContext): OrderBook {
        let id = new_uid(ctx);
        let asks = bp_tree_empty<Order>(branch_order, leaf_order, ctx);
        let bids = bp_tree_empty<Order>(branch_order, leaf_order, ctx);
        let counter = 0;

        OrderBook {
            id,
            asks,
            bids,
            counter,
        }
    }

    public fun add_to_post_receipt(post_receipt: &mut PostReceipt, is_ask: bool, size: u64) {
        if (is_ask) {
            post_receipt.base_ask = post_receipt.base_ask + size;
        } else {
            post_receipt.base_bid = post_receipt.base_bid + size;
        };
        post_receipt.pending_orders = post_receipt.pending_orders + 1;
    }

    public fun best_price(orderbook: &OrderBook, is_ask: bool): option::Option<u128> {
        let tree = if (is_ask) {
            &orderbook.asks
        } else {
            &orderbook.bids
        };

        let leaf_ptr = first_leaf_ptr(tree);

        if (leaf_ptr == 0) {
            return option::none()
        };

        let leaf = borrow_leaf(tree, leaf_ptr);
        let (best_key, _) = borrow_leaf_elem(leaf, 0);
        option::some(best_key)
    }

    public fun book_price(orderbook: &OrderBook): option::Option<u64> {
        // TODO: Implement function
        option::none()
    }

    public fun cancel_limit_order(orderbook: &mut OrderBook, account_id: address, order_id: u64): u64 {
        // TODO: Implement function
        0
    }

    public fun change_BPTrees_params(orderbook: &mut OrderBook, max_depth: u64, max_key: u64, max_value: u64, max_size: u64, max_load_factor: u64, max_load_factor_hard_limit: u64) {
        // TODO: Implement function
    }

    public fun create_empty_post_receipt(): PostReceipt {
        // TODO: Implement function
        PostReceipt {
            base_ask: 0,
            base_bid: 0,
            pending_orders: 0,
        }
    }

    public fun fill_limit_order(orderbook: &mut OrderBook, account_id: address, is_ask: bool, size: u64, price: u64, order_type: u64, fill_receipts: &mut vector<FillReceipt>): u64 {
        // TODO: Implement function
        0
    }

    public fun fill_market_order(orderbook: &mut OrderBook, account_id: address, is_ask: bool, size: u64, fill_receipts: &mut vector<FillReceipt>): u64 {
        // TODO: Implement function
        0
    }

    public fun get_asks(orderbook: &OrderBook): &BPTree<Order> {
        // TODO: Implement function
        &orderbook.asks
    }

    public fun get_bids(orderbook: &OrderBook): &BPTree<Order> {
        // TODO: Implement function
        &orderbook.bids
    }

    public fun get_asks_mut(orderbook: &mut OrderBook): &mut BPTree<Order> {
        // TODO: Implement function
        &mut orderbook.asks
    }

    public fun get_bids_mut(orderbook: &mut OrderBook): &mut BPTree<Order> {
        // TODO: Implement function
        &mut orderbook.bids
    }

    public fun get_fill_receipt_info(receipt: &FillReceipt): (address, u128, u64, u64) {
        // TODO: Implement function
        (receipt.account_id, receipt.order_id, receipt.size, receipt.final_size)
    }

    public fun get_order_size(orderbook: &OrderBook, order_id: u64): u64 {
        // TODO: Implement function
        0
    }

    public fun get_post_receipt_info(receipt: &PostReceipt): (u64, u64, u64) {
        // TODO: Implement function
        (receipt.base_ask, receipt.base_bid, receipt.pending_orders)
    }

    // public fun place_limit_order(orderbook: &mut OrderBook, account_id: address, is_ask: bool, size: u64, price: u64, order_type: u64, fill_receipts: &mut vector<FillReceipt>, post_receipt: &mut PostReceipt, market_id: &address): u64 {
    //     // TODO: Implement function
    // }

    public fun place_market_order(orderbook: &mut OrderBook, account_id: address, is_ask: bool, size: u64, fill_receipts: &mut vector<FillReceipt>) {
        let mut remaining_size = size;
        let orders_to_fill = if (is_ask) {
            &mut orderbook.bids
        } else {
            &mut orderbook.asks
        };

        let mut leaf_ptr = orders_to_fill.first_leaf_ptr();

        while (remaining_size > 0 && leaf_ptr != 0) {
            let leaf = orders_to_fill.borrow_leaf(leaf_ptr);
            let leaf_size = leaf_size(leaf);
            leaf_ptr = leaf_next(leaf);

            let mut i = 0;
            while (i < leaf_size && remaining_size > 0) {
                let leaf = orders_to_fill.borrow_leaf_mut(leaf_ptr);
                let (key, order) = borrow_leaf_elem_mut(leaf, i);
                let order_size = order.quantity;

                if (order_size <= remaining_size) {
                    // Fill the entire order
                    let fill_receipt = FillReceipt {
                        account_id: order.account_id,
                        order_id: key,
                        size: order_size,
                        final_size: order_size,
                    };
                    vector::push_back(fill_receipts, fill_receipt);
                    remaining_size = remaining_size - order_size;
                    orders_to_fill.remove(key);
                } else {
                    // Partially fill the order
                    let fill_receipt = FillReceipt {
                        account_id: order.account_id,
                        order_id: key,
                        size: remaining_size,
                        final_size: order_size,
                    };
                    vector::push_back(fill_receipts, fill_receipt);
                    order.quantity = order.quantity - remaining_size;
                    remaining_size = 0;
                };

                i = i + 1;
            };
        };

        assert!(remaining_size == 0, 0);
    }

    public fun post_order(orderbook: &mut OrderBook, account_id: address, is_ask: bool, size: u64, price: u64, post_receipt: &mut PostReceipt, market_id: &address) {
        // TODO: Implement function
    }
}
