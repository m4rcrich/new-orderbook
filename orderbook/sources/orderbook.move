#[allow(unused_variable)]
/// Module: orderbook
module orderbook::orderbook {
    use orderbook::bp_tree::{BPTree, empty, batch_drop, min_key, first_leaf_ptr, borrow_leaf_mut, is_empty, borrow_leaf_elem_mut, leaf_next, leaf_size, insert, remove};
    //remove(key, val), first_leaf_ptr, borrow_leaf, leaf_next, and update(key, val) need to be implemented in bp_tree

    #[allow(unused_field)]
    public struct Order has copy, drop, store {
        account_id: u64,
        size: u64,
    }
    
    public struct Orderbook has store, key {
        id: sui::object::UID,
        counter: u64,
    }
    
    public struct FillReceipt has drop, store {
        account_id: u64,
        order_id: u128,
        size: u64,
        final_size: u64,
    }
    
    public struct PostReceipt has drop, store {
        base_ask: u64,
        base_bid: u64,
        pending_orders: u64,
    }
    
    // public struct OrderInfo has copy, drop, store {
    //     price: u64,
    //     size: u64,
    // }

    public struct AsksMap has copy, drop, store {
        dummy_field: bool,
    }
    
    public struct BidsMap has copy, drop, store {
        dummy_field: bool,
    }

    fun asks_map() : AsksMap {
        AsksMap{dummy_field: false}
    }
    
    fun bids_map() : BidsMap {
        BidsMap{dummy_field: false}
    }

    public fun create_orderbook(children_order: u64, leaf_order:u64, ctx: &mut sui::tx_context::TxContext) : Orderbook {
        let mut orderbook = Orderbook{
            id      : sui::object::new(ctx), 
            counter : 0,
        };
        sui::dynamic_object_field::add<AsksMap, BPTree<Order>>(&mut orderbook.id, asks_map(), empty<Order>(children_order, leaf_order, ctx));
        sui::dynamic_object_field::add<BidsMap, BPTree<Order>>(&mut orderbook.id, bids_map(), empty<Order>(children_order, leaf_order, ctx));
        orderbook
    }

    public fun add_to_post_receipt(post_receipt: &mut PostReceipt, is_ask: bool, size: u64) {
        if (is_ask) {
            post_receipt.base_ask = post_receipt.base_ask + size;
        } else {
            post_receipt.base_bid = post_receipt.base_bid + size;
        };
        post_receipt.pending_orders = post_receipt.pending_orders + 1;
    }

    public fun best_price(orderbook: &Orderbook, is_ask: bool): option::Option<u64> {
        let orders = if (is_ask) {
            get_asks(orderbook)
        } else {
            get_bids(orderbook)
        };
        if(is_empty(orders)) {
            return option::none()
        };
        let best_price = if (is_ask) {
            ((min_key<Order>(orders)) >> 64) as u64
        } else {
            ((min_key<Order>(orders) >> 64) as u64) ^ 18446744073709551615
        };
        option::some<u64>(best_price)
    }

    public fun book_price(orderbook: &Orderbook) : option::Option<u64> {
        if (is_empty<Order>(get_bids(orderbook)) || is_empty<Order>(get_asks(orderbook))) {
            return option::none<u64>()
        };
        option::some<u64>((((min_key<Order>(get_asks(orderbook)) >> 64) as u64) + (((min_key<Order>(get_bids(orderbook))) >> 64) as u64) ^ 18446744073709551615) / 2)
    }

    fun is_ask(arg0: u128) : bool {
        arg0 < 170141183460469231731687303715884105728
    }

    public fun cancel_limit_order(orderbook: &mut Orderbook, account_id: u64, order_id: u128): u64 {
        // TODO: Implement function
        let orders = if (is_ask(order_id)) {
            get_asks_mut(orderbook)
        } else {
            get_bids_mut(orderbook)
        };
        let order = remove<Order>(orders, order_id);
        assert!(account_id == order.account_id, 3004); //invalid user for order
        order.size
    }

    public fun create_empty_post_receipt(): PostReceipt {
        // TODO: Implement function
        PostReceipt {
            base_ask: 0,
            base_bid: 0,
            pending_orders: 0,
        }
    }

    public fun post_only() : u64 {
        2
    }

    public fun fill_or_kill() : u64 {
        1
    }

    public fun immediate_or_cancel() : u64 {
        3
    }

    fun fill_limit_order(orderbook: &mut Orderbook, account_id: u64, is_ask: bool, mut size: u64, price: u64, order_type: u64, fill_receipts: &mut vector<FillReceipt>): u64 {
        let (orders, order_id) = if (is_ask) {
            (get_bids_mut(orderbook), ((price ^ 18446744073709551615) as u128))
        } else {
            (get_asks_mut(orderbook), (price as u128))
        };
        if (order_type == post_only()) {
            if (!is_empty<Order>(orders)) {
                assert!(min_key<Order>(orders) >> 64 > order_id, 3005); //flag requirements violated
            };
            return size
        };
        let mut last_order_id = 0;
        let mut remove_last_order = true;
        let mut leaf_ptr = first_leaf_ptr<Order>(orders);
        let mut stop_filling = false;
        while (leaf_ptr != 0) {
            let leaf = borrow_leaf_mut<Order>(orders, leaf_ptr);
            leaf_ptr = leaf_next<Order>(leaf);
            let mut index = 0;
            while (index < leaf_size<Order>(leaf)) {
                let (order_id, order) = borrow_leaf_elem_mut<Order>(leaf, index);
                if (order_id >> 64 > order_id) {
                    stop_filling = true;
                    break
                };
                assert!(account_id != order.account_id, 3008); //self trading
                last_order_id = order_id;
                if (size >= order.size) {
                    let fill_receipt = FillReceipt{
                        account_id : order.account_id, 
                        order_id   : order_id, 
                        size       : order.size, 
                        final_size : 0,
                    };
                    std::vector::push_back<FillReceipt>(fill_receipts, fill_receipt);
                    let remaining_size = size - order.size;
                    size = remaining_size;
                    if (remaining_size == 0) {
                        break
                    };
                    index = index + 1;
                } else {
                    order.size = order.size - size;
                    let fill_receipt = FillReceipt{
                        account_id : order.account_id, 
                        order_id   : order_id, 
                        size       : size, 
                        final_size : order.size,
                    };
                    std::vector::push_back<FillReceipt>(fill_receipts, fill_receipt);
                    size = 0;
                    remove_last_order = false;
                    break
                };
            };
            if (stop_filling || size == 0) {
                break
            };
        };
        if (order_type == fill_or_kill()) {
            assert!(size == 0, 3005); //flag requirements violated
        };
        if (last_order_id > 0) {
            batch_drop<Order>(orders, last_order_id, remove_last_order);
        };
        if (order_type == immediate_or_cancel()) {
            size = 0;
        };
        size
    }

    fun fill_market_order(orderbook: &mut Orderbook, account_id: u64, is_ask: bool, mut size: u64, fill_receipts: &mut vector<FillReceipt>) {
        // TODO: Implement function
        let mut last_order_id = 0;
        let mut remove_last_order = true;
        let orders = if (is_ask) {
            get_bids_mut(orderbook)
        } else {
            get_asks_mut(orderbook)
        };
        let mut leaf_ptr = first_leaf_ptr<Order>(orders);
        while (leaf_ptr != 0) {
            let leaf = borrow_leaf_mut<Order>(orders, leaf_ptr);
            leaf_ptr = leaf_next<Order>(leaf);
            let mut index = 0;
            while (index < leaf_size<Order>(leaf)) {
                let (order_id, order) = borrow_leaf_elem_mut<Order>(leaf, index);
                last_order_id = order_id;
                assert!(account_id != order.account_id, 3008); //self trading
                if (size >= order.size) {
                    let fill_receipt = FillReceipt{
                        account_id : order.account_id, 
                        order_id   : order_id, 
                        size       : order.size, 
                        final_size : 0,
                    };
                    std::vector::push_back<FillReceipt>(fill_receipts, fill_receipt);
                    let remaining_size = size - order.size;
                    size = remaining_size;
                    if (remaining_size == 0) {
                        break
                    };
                    index = index + 1;
                } else {
                    order.size = order.size - size;
                    let fill_receipt = FillReceipt{
                        account_id : order.account_id, 
                        order_id   : order_id, 
                        size       : size, 
                        final_size : order.size,
                    };
                    std::vector::push_back<FillReceipt>(fill_receipts, fill_receipt);
                    size = 0;
                    remove_last_order = false;
                    break
                };
            };
            if (size == 0) {
                break
            };
        };
        assert!(size == 0, 3006); //not enough liquidity
        if (last_order_id > 0) {
            batch_drop<Order>(orders, last_order_id, remove_last_order);
        };
    }

    public fun place_market_order(orderbook: &mut Orderbook, account_id: u64, is_ask: bool, size: u64, fill_receipts: &mut vector<FillReceipt>) {
        fill_market_order(orderbook, account_id, is_ask, size, fill_receipts);
    }

    public fun place_limit_order(orderbook: &mut Orderbook, account_id: u64, is_ask: bool, size: u64, price: u64, order_type: u64, fill_receipts: &mut vector<FillReceipt>, post_receipt: &mut PostReceipt, market_id: &sui::object::ID) : u64 {
        assert!(order_type < 4, 3005); //flag requirements violated
        let remaining_size = fill_limit_order(orderbook, account_id, is_ask, size, price, order_type, fill_receipts);
        post_order(orderbook, account_id, is_ask, remaining_size, price, post_receipt, market_id);
        remaining_size
    }

    fun get_asks(orderbook: &Orderbook) : &BPTree<Order> {
        sui::dynamic_object_field::borrow<AsksMap, BPTree<Order>>(&orderbook.id, asks_map())
    }
    
    fun get_asks_mut(orderbook: &mut Orderbook) : &mut BPTree<Order> {
        sui::dynamic_object_field::borrow_mut<AsksMap, BPTree<Order>>(&mut orderbook.id, asks_map())
    }
    
    fun get_bids(orderbook: &Orderbook) : &BPTree<Order> {
        sui::dynamic_object_field::borrow<BidsMap, BPTree<Order>>(&orderbook.id, bids_map())
    }
    
    fun get_bids_mut(orderbook: &mut Orderbook) : &mut BPTree<Order> {
        sui::dynamic_object_field::borrow_mut<BidsMap, BPTree<Order>>(&mut orderbook.id, bids_map())
    }

    public fun get_fill_receipt_info(fill_receipt: &FillReceipt) : (u64, u128, u64, u64) {
        (fill_receipt.account_id, fill_receipt.order_id, fill_receipt.size, fill_receipt.final_size)
    }

    public fun get_post_receipt_info(post_receipt: &PostReceipt) : (u64, u64, u64) {
        (post_receipt.base_ask, post_receipt.base_bid, post_receipt.pending_orders)
    }

    public fun post_order(orderbook: &mut Orderbook, account_id: u64, is_ask: bool, size: u64, price: u64, post_receipt: &mut PostReceipt, market_id: &sui::object::ID) {
        if (size == 0) {
            return
        };
        let (orders, order_id) = if (is_ask) {
            let order_id = order_id_ask(price, increase_counter(&mut orderbook.counter));
            (get_asks_mut(orderbook), order_id)
        } else {
            let order_id = order_id_bid(price, increase_counter(&mut orderbook.counter));
            (get_bids_mut(orderbook), order_id)
        };
        let order = Order{
            account_id : account_id, 
            size       : size,
        };
        insert<Order>(orders, order_id, order);
        add_to_post_receipt(post_receipt, is_ask, size);
    }

    fun order_id_ask(arg0: u64, arg1: u64) : u128 {
        assert!(arg0 < 9223372036854775808, 1); //invalid size or price
        (arg0 as u128) << 64 | (arg1 as u128)
    }
    
    fun order_id_bid(arg0: u64, arg1: u64) : u128 {
        assert!(arg0 < 9223372036854775808, 1); //invalid size or price
        ((arg0 ^ 18446744073709551615) as u128) << 64 | (arg1 as u128)
    }

    fun increase_counter(counter: &mut u64) : u64 {
        *counter = *counter + 1;
        *counter
    }
}
