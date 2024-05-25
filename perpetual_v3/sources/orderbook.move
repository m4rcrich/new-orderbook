#[allow(unused_variable)]
module perpetual_v3::orderbook {

    struct Order has copy, drop, store {
        account_id: u64,
        size: u64,
    }
    
    struct Orderbook has store, key {
        id: sui::object::UID,
        counter: u64,
    }
    
    struct FillReceipt has drop, store {
        account_id: u64,
        order_id: u128,
        size: u64,
        final_size: u64,
    }
    
    struct PostReceipt has drop, store {
        base_ask: u64,
        base_bid: u64,
        pending_orders: u64,
    }
    
    struct OrderInfo has copy, drop, store {
        price: u64,
        size: u64,
    }
    
    fun add_to_post_receipt(post_receipt: &mut PostReceipt, is_ask: bool, size: u64) {
        if (is_ask == perpetual_v3::constants::ask()) {
            post_receipt.base_ask = post_receipt.base_ask + size;
        } else {
            post_receipt.base_bid = post_receipt.base_bid + size;
        };
        post_receipt.pending_orders = post_receipt.pending_orders + 1;
    }
    
    public fun best_price(orderbook: &Orderbook, is_ask: bool) : std::option::Option<u64> {
        let orders = if (is_ask == perpetual_v3::constants::ask()) {
            get_asks(orderbook)
        } else {
            get_bids(orderbook)
        };
        if (perpetual_v3::ordered_map::is_empty<Order>(orders)) {
            return std::option::none<u64>()
        };
        let best_price = if (is_ask == perpetual_v3::constants::ask()) {
            perpetual_v3::order_id::price_ask(perpetual_v3::ordered_map::min_key<Order>(orders))
        } else {
            perpetual_v3::order_id::price_bid(perpetual_v3::ordered_map::min_key<Order>(orders))
        };
        std::option::some<u64>(best_price)
    }
    
    public fun book_price(orderbook: &Orderbook) : std::option::Option<u64> {
        if (perpetual_v3::ordered_map::is_empty<Order>(get_bids(orderbook)) || perpetual_v3::ordered_map::is_empty<Order>(get_asks(orderbook))) {
            return std::option::none<u64>()
        };
        std::option::some<u64>((perpetual_v3::order_id::price_ask(perpetual_v3::ordered_map::min_key<Order>(get_asks(orderbook))) + perpetual_v3::order_id::price_bid(perpetual_v3::ordered_map::min_key<Order>(get_bids(orderbook)))) / 2)
    }
    
    public fun cancel_limit_order(orderbook: &mut Orderbook, account_id: u64, order_id: u128) : u64 {
        let orders = if (perpetual_v3::order_id::is_ask(order_id)) {
            get_asks_mut(orderbook)
        } else {
            get_bids_mut(orderbook)
        };
        let order = perpetual_v3::ordered_map::remove<Order>(orders, order_id);
        assert!(account_id == order.account_id, perpetual_v3::errors::invalid_user_for_order());
        order.size
    }
    
    public fun change_maps_params(orderbook: &mut Orderbook, max_depth: u64, max_key: u64, max_value: u64, max_size: u64, max_load_factor: u64, max_load_factor_hard_limit: u64) {
        perpetual_v3::ordered_map::change_params<Order>(get_asks_mut(orderbook), max_depth, max_key, max_value, max_size, max_load_factor, max_load_factor_hard_limit);
        perpetual_v3::ordered_map::change_params<Order>(get_bids_mut(orderbook), max_depth, max_key, max_value, max_size, max_load_factor, max_load_factor_hard_limit);
    }
    
    public fun create_empty_post_receipt() : PostReceipt {
        PostReceipt{
            base_ask       : 0, 
            base_bid       : 0, 
            pending_orders : 0,
        }
    }
    
    public fun create_orderbook(max_depth: u64, max_key: u64, max_value: u64, max_size: u64, max_load_factor: u64, max_load_factor_hard_limit: u64, ctx: &mut sui::tx_context::TxContext) : Orderbook {
        let orderbook = Orderbook{
            id      : sui::object::new(ctx), 
            counter : 0,
        };
        sui::dynamic_object_field::add<perpetual_v3::keys::AsksMap, perpetual_v3::ordered_map::Map<Order>>(&mut orderbook.id, perpetual_v3::keys::asks_map(), perpetual_v3::ordered_map::empty<Order>(max_depth, max_key, max_value, max_size, max_load_factor, max_load_factor_hard_limit, ctx));
        sui::dynamic_object_field::add<perpetual_v3::keys::BidsMap, perpetual_v3::ordered_map::Map<Order>>(&mut orderbook.id, perpetual_v3::keys::bids_map(), perpetual_v3::ordered_map::empty<Order>(max_depth, max_key, max_value, max_size, max_load_factor, max_load_factor_hard_limit, ctx));
        perpetual_v3::events::emit_created_orderbook(max_depth, max_key, max_value, max_size, max_load_factor, max_load_factor_hard_limit);
        orderbook
    }
    
    fun fill_limit_order(orderbook: &mut Orderbook, account_id: u64, is_ask: bool, size: u64, price: u64, order_type: u64, fill_receipts: &mut vector<FillReceipt>) : u64 {
        let (orders, order_id) = if (is_ask == perpetual_v3::constants::ask()) {
            (get_bids_mut(orderbook), ((price ^ 18446744073709551615) as u128))
        } else {
            (get_asks_mut(orderbook), (price as u128))
        };
        if (order_type == perpetual_v3::constants::post_only()) {
            if (!perpetual_v3::ordered_map::is_empty<Order>(orders)) {
                assert!(perpetual_v3::ordered_map::min_key<Order>(orders) >> 64 > order_id, perpetual_v3::errors::flag_requirements_violated());
            };
            return size
        };
        let last_order_id = 0;
        let remove_last_order = true;
        let leaf_ptr = perpetual_v3::ordered_map::first_leaf_ptr<Order>(orders);
        let stop_filling = false;
        while (leaf_ptr != 0) {
            let leaf = perpetual_v3::ordered_map::get_leaf_mut<Order>(orders, leaf_ptr);
            leaf_ptr = perpetual_v3::ordered_map::leaf_next<Order>(leaf);
            let index = 0;
            while (index < perpetual_v3::ordered_map::leaf_size<Order>(leaf)) {
                let (order_id, order) = perpetual_v3::ordered_map::leaf_elem_mut<Order>(leaf, index);
                if (order_id >> 64 > order_id) {
                    stop_filling = true;
                    break
                };
                assert!(account_id != order.account_id, perpetual_v3::errors::self_trading());
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
        if (order_type == perpetual_v3::constants::fill_or_kill()) {
            assert!(size == 0, perpetual_v3::errors::flag_requirements_violated());
        };
        if (last_order_id > 0) {
            perpetual_v3::ordered_map::batch_drop<Order>(orders, last_order_id, remove_last_order);
        };
        if (order_type == perpetual_v3::constants::immediate_or_cancel()) {
            size = 0;
        };
        size
    }
    
    fun fill_market_order(orderbook: &mut Orderbook, account_id: u64, is_ask: bool, size: u64, fill_receipts: &mut vector<FillReceipt>) {
        let last_order_id = 0;
        let remove_last_order = true;
        let orders = if (is_ask == perpetual_v3::constants::ask()) {
            get_bids_mut(orderbook)
        } else {
            get_asks_mut(orderbook)
        };
        let leaf_ptr = perpetual_v3::ordered_map::first_leaf_ptr<Order>(orders);
        while (leaf_ptr != 0) {
            let leaf = perpetual_v3::ordered_map::get_leaf_mut<Order>(orders, leaf_ptr);
            leaf_ptr = perpetual_v3::ordered_map::leaf_next<Order>(leaf);
            let index = 0;
            while (index < perpetual_v3::ordered_map::leaf_size<Order>(leaf)) {
                let (order_id, order) = perpetual_v3::ordered_map::leaf_elem_mut<Order>(leaf, index);
                last_order_id = order_id;
                assert!(account_id != order.account_id, perpetual_v3::errors::self_trading());
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
        assert!(size == 0, perpetual_v3::errors::not_enough_liquidity());
        if (last_order_id > 0) {
            perpetual_v3::ordered_map::batch_drop<Order>(orders, last_order_id, remove_last_order);
        };
    }
    
    fun get_asks(orderbook: &Orderbook) : &perpetual_v3::ordered_map::Map<Order> {
        sui::dynamic_object_field::borrow<perpetual_v3::keys::AsksMap, perpetual_v3::ordered_map::Map<Order>>(&orderbook.id, perpetual_v3::keys::asks_map())
    }
    
    fun get_asks_mut(orderbook: &mut Orderbook) : &mut perpetual_v3::ordered_map::Map<Order> {
        sui::dynamic_object_field::borrow_mut<perpetual_v3::keys::AsksMap, perpetual_v3::ordered_map::Map<Order>>(&mut orderbook.id, perpetual_v3::keys::asks_map())
    }
    
    fun get_bids(orderbook: &Orderbook) : &perpetual_v3::ordered_map::Map<Order> {
        sui::dynamic_object_field::borrow<perpetual_v3::keys::BidsMap, perpetual_v3::ordered_map::Map<Order>>(&orderbook.id, perpetual_v3::keys::bids_map())
    }
    
    fun get_bids_mut(orderbook: &mut Orderbook) : &mut perpetual_v3::ordered_map::Map<Order> {
        sui::dynamic_object_field::borrow_mut<perpetual_v3::keys::BidsMap, perpetual_v3::ordered_map::Map<Order>>(&mut orderbook.id, perpetual_v3::keys::bids_map())
    }
    
    public fun get_fill_receipt_info(fill_receipt: &FillReceipt) : (u64, u128, u64, u64) {
        (fill_receipt.account_id, fill_receipt.order_id, fill_receipt.size, fill_receipt.final_size)
    }
    
    public fun get_order_size(orderbook: &Orderbook, order_id: u128) : u64 {
        let order = if (perpetual_v3::order_id::is_ask(order_id) == perpetual_v3::constants::ask()) {
            perpetual_v3::ordered_map::borrow<Order>(get_asks(orderbook), order_id)
        } else {
            perpetual_v3::ordered_map::borrow<Order>(get_bids(orderbook), order_id)
        };
        order.size
    }

    public fun get_post_receipt_info(post_receipt: &PostReceipt) : (u64, u64, u64) {
        (post_receipt.base_ask, post_receipt.base_bid, post_receipt.pending_orders)
    }

    fun increase_counter(counter: &mut u64) : u64 {
        *counter = *counter + 1;
        *counter
    }

    public fun inspect_orders(orderbook: &Orderbook, is_ask: bool, start_price: u64, end_price: u64) : vector<OrderInfo> {
        let order_infos = std::vector::empty<OrderInfo>();
        let (orders, start_order_id, end_order_id) = if (is_ask == perpetual_v3::constants::ask()) {
            (get_asks(orderbook), perpetual_v3::order_id::order_id_ask(start_price, 0), end_price)
        } else {
            (get_bids(orderbook), perpetual_v3::order_id::order_id_bid(start_price, 0), end_price ^ 18446744073709551615)
        };
        let leaf = perpetual_v3::ordered_map::get_leaf<Order>(orders, perpetual_v3::ordered_map::find_leaf<Order>(orders, start_order_id));
        let current_leaf = leaf;
        let index = perpetual_v3::ordered_map::leaf_find_index<Order>(leaf, start_order_id);
        loop {
            while (index < perpetual_v3::ordered_map::leaf_size<Order>(current_leaf)) {
                let (order_id, order) = perpetual_v3::ordered_map::leaf_elem<Order>(current_leaf, index);
                let price = ((order_id >> 64) as u64);
                let display_price = price;
                if (price >= end_order_id) {
                    return order_infos
                };
                if (is_ask == perpetual_v3::constants::bid()) {
                    display_price = price ^ 18446744073709551615;
                };
                let order_info = OrderInfo{
                    price : display_price, 
                    size  : order.size,
                };
                std::vector::push_back<OrderInfo>(&mut order_infos, order_info);
                index = index + 1;
            };
            let next_leaf_ptr = perpetual_v3::ordered_map::leaf_next<Order>(current_leaf);
            if (next_leaf_ptr == 0) {
                break
            };
            current_leaf = perpetual_v3::ordered_map::get_leaf<Order>(orders, next_leaf_ptr);
            index = 0;
        };
        order_infos
    }

    public fun place_limit_order(orderbook: &mut Orderbook, account_id: u64, is_ask: bool, size: u64, price: u64, order_type: u64, fill_receipts: &mut vector<FillReceipt>, post_receipt: &mut PostReceipt, market_id: &sui::object::ID) : u64 {
        assert!(order_type < perpetual_v3::constants::order_types(), perpetual_v3::errors::flag_requirements_violated());
        let remaining_size = fill_limit_order(orderbook, account_id, is_ask, size, price, order_type, fill_receipts);
        post_order(orderbook, account_id, is_ask, remaining_size, price, post_receipt, market_id);
        remaining_size
    }

    public fun place_market_order(orderbook: &mut Orderbook, account_id: u64, is_ask: bool, size: u64, fill_receipts: &mut vector<FillReceipt>) {
        fill_market_order(orderbook, account_id, is_ask, size, fill_receipts);
    }

    fun post_order(orderbook: &mut Orderbook, account_id: u64, is_ask: bool, size: u64, price: u64, post_receipt: &mut PostReceipt, market_id: &sui::object::ID) {
        if (size == 0) {
            return
        };
        let (orders, order_id) = if (is_ask == perpetual_v3::constants::ask()) {
            let order_id = perpetual_v3::order_id::order_id_ask(price, increase_counter(&mut orderbook.counter));
            (get_asks_mut(orderbook), order_id)
        } else {
            let order_id = perpetual_v3::order_id::order_id_bid(price, increase_counter(&mut orderbook.counter));
            (get_bids_mut(orderbook), order_id)
        };
        let order = Order{
            account_id : account_id, 
            size       : size,
        };
        perpetual_v3::ordered_map::insert<Order>(orders, order_id, order);
        add_to_post_receipt(post_receipt, is_ask, size);
        perpetual_v3::events::emit_orderbook_post_receipt(*market_id, account_id, order_id, size);
    }
    
    // decompiled from Move bytecode v6
}

