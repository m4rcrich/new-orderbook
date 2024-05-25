module perpetual_v3::orderbook {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};
    friend perpetual_v3::account;
    friend perpetual_v3::admin;
    friend perpetual_v3::clearing_house;
    friend perpetual_v3::constants;
    friend perpetual_v3::errors;
    friend perpetual_v3::events;
    friend perpetual_v3::interface;
    friend perpetual_v3::keys;
    friend perpetual_v3::market;
    friend perpetual_v3::oracle;
    friend perpetual_v3::order_id;
    friend perpetual_v3::ordered_map;
    friend perpetual_v3::position;
    friend perpetual_v3::registry;
    friend perpetual_v3::subaccount;

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
    
    fun add_to_post_receipt(arg0: &mut PostReceipt, arg1: bool, arg2: u64) {
        if (arg1 == perpetual_v3::constants::ask()) {
            arg0.base_ask = arg0.base_ask + arg2;
        } else {
            arg0.base_bid = arg0.base_bid + arg2;
        };
        arg0.pending_orders = arg0.pending_orders + 1;
    }
    
    public fun best_price(arg0: &Orderbook, arg1: bool) : std::option::Option<u64> {
        let v0 = if (arg1 == perpetual_v3::constants::ask()) {
            get_asks(arg0)
        } else {
            get_bids(arg0)
        };
        if (perpetual_v3::ordered_map::is_empty<Order>(v0)) {
            return std::option::none<u64>()
        };
        let v1 = if (arg1 == perpetual_v3::constants::ask()) {
            perpetual_v3::order_id::price_ask(perpetual_v3::ordered_map::min_key<Order>(v0))
        } else {
            perpetual_v3::order_id::price_bid(perpetual_v3::ordered_map::min_key<Order>(v0))
        };
        std::option::some<u64>(v1)
    }
    
    public fun book_price(arg0: &Orderbook) : std::option::Option<u64> {
        if (perpetual_v3::ordered_map::is_empty<Order>(get_bids(arg0)) || perpetual_v3::ordered_map::is_empty<Order>(get_asks(arg0))) {
            return std::option::none<u64>()
        };
        std::option::some<u64>((perpetual_v3::order_id::price_ask(perpetual_v3::ordered_map::min_key<Order>(get_asks(arg0))) + perpetual_v3::order_id::price_bid(perpetual_v3::ordered_map::min_key<Order>(get_bids(arg0)))) / 2)
    }
    
    public(friend) fun cancel_limit_order(arg0: &mut Orderbook, arg1: u64, arg2: u128) : u64 {
        let v0 = if (perpetual_v3::order_id::is_ask(arg2)) {
            get_asks_mut(arg0)
        } else {
            get_bids_mut(arg0)
        };
        let v1 = perpetual_v3::ordered_map::remove<Order>(v0, arg2);
        assert!(arg1 == v1.account_id, perpetual_v3::errors::invalid_user_for_order());
        v1.size
    }
    
    public(friend) fun change_maps_params(arg0: &mut Orderbook, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64, arg6: u64) {
        perpetual_v3::ordered_map::change_params<Order>(get_asks_mut(arg0), arg1, arg2, arg3, arg4, arg5, arg6);
        perpetual_v3::ordered_map::change_params<Order>(get_bids_mut(arg0), arg1, arg2, arg3, arg4, arg5, arg6);
    }
    
    public(friend) fun create_empty_post_receipt() : PostReceipt {
        PostReceipt{
            base_ask       : 0, 
            base_bid       : 0, 
            pending_orders : 0,
        }
    }
    
    public(friend) fun create_orderbook(arg0: u64, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64, arg6: &mut sui::tx_context::TxContext) : Orderbook {
        let v0 = Orderbook{
            id      : sui::object::new(arg6), 
            counter : 0,
        };
        sui::dynamic_object_field::add<perpetual_v3::keys::AsksMap, perpetual_v3::ordered_map::Map<Order>>(&mut v0.id, perpetual_v3::keys::asks_map(), perpetual_v3::ordered_map::empty<Order>(arg0, arg1, arg2, arg3, arg4, arg5, arg6));
        sui::dynamic_object_field::add<perpetual_v3::keys::BidsMap, perpetual_v3::ordered_map::Map<Order>>(&mut v0.id, perpetual_v3::keys::bids_map(), perpetual_v3::ordered_map::empty<Order>(arg0, arg1, arg2, arg3, arg4, arg5, arg6));
        perpetual_v3::events::emit_created_orderbook(arg0, arg1, arg2, arg3, arg4, arg5);
        v0
    }
    
    fun fill_limit_order(arg0: &mut Orderbook, arg1: u64, arg2: bool, arg3: u64, arg4: u64, arg5: u64, arg6: &mut vector<FillReceipt>) : u64 {
        let (v0, v1) = if (arg2 == perpetual_v3::constants::ask()) {
            (get_bids_mut(arg0), ((arg4 ^ 18446744073709551615) as u128))
        } else {
            (get_asks_mut(arg0), (arg4 as u128))
        };
        if (arg5 == perpetual_v3::constants::post_only()) {
            if (!perpetual_v3::ordered_map::is_empty<Order>(v0)) {
                assert!(perpetual_v3::ordered_map::min_key<Order>(v0) >> 64 > v1, perpetual_v3::errors::flag_requirements_violated());
            };
            return arg3
        };
        let v2 = 0;
        let v3 = true;
        let v4 = perpetual_v3::ordered_map::first_leaf_ptr<Order>(v0);
        let v5 = false;
        while (v4 != 0) {
            let v6 = perpetual_v3::ordered_map::get_leaf_mut<Order>(v0, v4);
            v4 = perpetual_v3::ordered_map::leaf_next<Order>(v6);
            let v7 = 0;
            while (v7 < perpetual_v3::ordered_map::leaf_size<Order>(v6)) {
                let (v8, v9) = perpetual_v3::ordered_map::leaf_elem_mut<Order>(v6, v7);
                if (v8 >> 64 > v1) {
                    v5 = true;
                    break
                };
                assert!(arg1 != v9.account_id, perpetual_v3::errors::self_trading());
                v2 = v8;
                if (arg3 >= v9.size) {
                    let v10 = FillReceipt{
                        account_id : v9.account_id, 
                        order_id   : v8, 
                        size       : v9.size, 
                        final_size : 0,
                    };
                    std::vector::push_back<FillReceipt>(arg6, v10);
                    let v11 = arg3 - v9.size;
                    arg3 = v11;
                    if (v11 == 0) {
                        break
                    };
                    v7 = v7 + 1;
                } else {
                    v9.size = v9.size - arg3;
                    let v12 = FillReceipt{
                        account_id : v9.account_id, 
                        order_id   : v8, 
                        size       : arg3, 
                        final_size : v9.size,
                    };
                    std::vector::push_back<FillReceipt>(arg6, v12);
                    arg3 = 0;
                    v3 = false;
                    break
                };
            };
            if (v5 || arg3 == 0) {
                break
            };
        };
        if (arg5 == perpetual_v3::constants::fill_or_kill()) {
            assert!(arg3 == 0, perpetual_v3::errors::flag_requirements_violated());
        };
        if (v2 > 0) {
            perpetual_v3::ordered_map::batch_drop<Order>(v0, v2, v3);
        };
        if (arg5 == perpetual_v3::constants::immediate_or_cancel()) {
            arg3 = 0;
        };
        arg3
    }
    
    fun fill_market_order(arg0: &mut Orderbook, arg1: u64, arg2: bool, arg3: u64, arg4: &mut vector<FillReceipt>) {
        let v0 = 0;
        let v1 = true;
        let v2 = if (arg2 == perpetual_v3::constants::ask()) {
            get_bids_mut(arg0)
        } else {
            get_asks_mut(arg0)
        };
        let v3 = perpetual_v3::ordered_map::first_leaf_ptr<Order>(v2);
        while (v3 != 0) {
            let v4 = perpetual_v3::ordered_map::get_leaf_mut<Order>(v2, v3);
            v3 = perpetual_v3::ordered_map::leaf_next<Order>(v4);
            let v5 = 0;
            while (v5 < perpetual_v3::ordered_map::leaf_size<Order>(v4)) {
                let (v6, v7) = perpetual_v3::ordered_map::leaf_elem_mut<Order>(v4, v5);
                v0 = v6;
                assert!(arg1 != v7.account_id, perpetual_v3::errors::self_trading());
                if (arg3 >= v7.size) {
                    let v8 = FillReceipt{
                        account_id : v7.account_id, 
                        order_id   : v6, 
                        size       : v7.size, 
                        final_size : 0,
                    };
                    std::vector::push_back<FillReceipt>(arg4, v8);
                    let v9 = arg3 - v7.size;
                    arg3 = v9;
                    if (v9 == 0) {
                        break
                    };
                    v5 = v5 + 1;
                } else {
                    v7.size = v7.size - arg3;
                    let v10 = FillReceipt{
                        account_id : v7.account_id, 
                        order_id   : v6, 
                        size       : arg3, 
                        final_size : v7.size,
                    };
                    std::vector::push_back<FillReceipt>(arg4, v10);
                    arg3 = 0;
                    v1 = false;
                    break
                };
            };
            if (arg3 == 0) {
                break
            };
        };
        assert!(arg3 == 0, perpetual_v3::errors::not_enough_liquidity());
        if (v0 > 0) {
            perpetual_v3::ordered_map::batch_drop<Order>(v2, v0, v1);
        };
    }
    
    fun get_asks(arg0: &Orderbook) : &perpetual_v3::ordered_map::Map<Order> {
        sui::dynamic_object_field::borrow<perpetual_v3::keys::AsksMap, perpetual_v3::ordered_map::Map<Order>>(&arg0.id, perpetual_v3::keys::asks_map())
    }
    
    fun get_asks_mut(arg0: &mut Orderbook) : &mut perpetual_v3::ordered_map::Map<Order> {
        sui::dynamic_object_field::borrow_mut<perpetual_v3::keys::AsksMap, perpetual_v3::ordered_map::Map<Order>>(&mut arg0.id, perpetual_v3::keys::asks_map())
    }
    
    fun get_bids(arg0: &Orderbook) : &perpetual_v3::ordered_map::Map<Order> {
        sui::dynamic_object_field::borrow<perpetual_v3::keys::BidsMap, perpetual_v3::ordered_map::Map<Order>>(&arg0.id, perpetual_v3::keys::bids_map())
    }
    
    fun get_bids_mut(arg0: &mut Orderbook) : &mut perpetual_v3::ordered_map::Map<Order> {
        sui::dynamic_object_field::borrow_mut<perpetual_v3::keys::BidsMap, perpetual_v3::ordered_map::Map<Order>>(&mut arg0.id, perpetual_v3::keys::bids_map())
    }
    
    public fun get_fill_receipt_info(arg0: &FillReceipt) : (u64, u128, u64, u64) {
        (arg0.account_id, arg0.order_id, arg0.size, arg0.final_size)
    }
    
    public fun get_order_size(arg0: &Orderbook, arg1: u128) : u64 {
        let v0 = if (perpetual_v3::order_id::is_ask(arg1) == perpetual_v3::constants::ask()) {
            perpetual_v3::ordered_map::borrow<Order>(get_asks(arg0), arg1)
        } else {
            perpetual_v3::ordered_map::borrow<Order>(get_bids(arg0), arg1)
        };
        v0.size
    }
    
    public fun get_post_receipt_info(arg0: &PostReceipt) : (u64, u64, u64) {
        (arg0.base_ask, arg0.base_bid, arg0.pending_orders)
    }
    
    fun increase_counter(arg0: &mut u64) : u64 {
        *arg0 = *arg0 + 1;
        *arg0
    }
    
    public(friend) fun inspect_orders(arg0: &Orderbook, arg1: bool, arg2: u64, arg3: u64) : vector<OrderInfo> {
        let v0 = std::vector::empty<OrderInfo>();
        let (v1, v2, v3) = if (arg1 == perpetual_v3::constants::ask()) {
            (get_asks(arg0), perpetual_v3::order_id::order_id_ask(arg2, 0), arg3)
        } else {
            (get_bids(arg0), perpetual_v3::order_id::order_id_bid(arg2, 0), arg3 ^ 18446744073709551615)
        };
        let v4 = perpetual_v3::ordered_map::get_leaf<Order>(v1, perpetual_v3::ordered_map::find_leaf<Order>(v1, v2));
        let v5 = v4;
        let v6 = perpetual_v3::ordered_map::leaf_find_index<Order>(v4, v2);
        loop {
            while (v6 < perpetual_v3::ordered_map::leaf_size<Order>(v5)) {
                let (v7, v8) = perpetual_v3::ordered_map::leaf_elem<Order>(v5, v6);
                let v9 = ((v7 >> 64) as u64);
                let v10 = v9;
                if (v9 >= v3) {
                    return v0
                };
                if (arg1 == perpetual_v3::constants::bid()) {
                    v10 = v9 ^ 18446744073709551615;
                };
                let v11 = OrderInfo{
                    price : v10, 
                    size  : v8.size,
                };
                std::vector::push_back<OrderInfo>(&mut v0, v11);
                v6 = v6 + 1;
            };
            let v12 = perpetual_v3::ordered_map::leaf_next<Order>(v5);
            if (v12 == 0) {
                break
            };
            v5 = perpetual_v3::ordered_map::get_leaf<Order>(v1, v12);
            v6 = 0;
        };
        v0
    }
    
    public(friend) fun place_limit_order(arg0: &mut Orderbook, arg1: u64, arg2: bool, arg3: u64, arg4: u64, arg5: u64, arg6: &mut vector<FillReceipt>, arg7: &mut PostReceipt, arg8: &sui::object::ID) : u64 {
        assert!(arg5 < perpetual_v3::constants::order_types(), perpetual_v3::errors::flag_requirements_violated());
        let v0 = fill_limit_order(arg0, arg1, arg2, arg3, arg4, arg5, arg6);
        post_order(arg0, arg1, arg2, v0, arg4, arg7, arg8);
        v0
    }
    
    public(friend) fun place_market_order(arg0: &mut Orderbook, arg1: u64, arg2: bool, arg3: u64, arg4: &mut vector<FillReceipt>) {
        fill_market_order(arg0, arg1, arg2, arg3, arg4);
    }
    
    fun post_order(arg0: &mut Orderbook, arg1: u64, arg2: bool, arg3: u64, arg4: u64, arg5: &mut PostReceipt, arg6: &sui::object::ID) {
        if (arg3 == 0) {
            return
        };
        let (v0, v1) = if (arg2 == perpetual_v3::constants::ask()) {
            (get_asks_mut(arg0), perpetual_v3::order_id::order_id_ask(arg4, increase_counter(&mut arg0.counter)))
        } else {
            (get_bids_mut(arg0), perpetual_v3::order_id::order_id_bid(arg4, increase_counter(&mut arg0.counter)))
        };
        let v2 = Order{
            account_id : arg1, 
            size       : arg3,
        };
        perpetual_v3::ordered_map::insert<Order>(v0, v1, v2);
        add_to_post_receipt(arg5, arg2, arg3);
        perpetual_v3::events::emit_orderbook_post_receipt(*arg6, arg1, v1, arg3);
    }
    
    // decompiled from Move bytecode v6
}

