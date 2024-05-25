module perpetual_v3::order_id {
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
    friend perpetual_v3::orderbook;
    friend perpetual_v3::ordered_map;
    friend perpetual_v3::position;
    friend perpetual_v3::registry;
    friend perpetual_v3::subaccount;

    public fun order_id(arg0: u64, arg1: u64, arg2: bool) : u128 {
        if (arg2 == perpetual_v3::constants::ask()) {
            order_id_ask(arg0, arg1)
        } else {
            order_id_bid(arg0, arg1)
        }
    }
    
    public fun counter(arg0: u128) : u64 {
        ((arg0 & 18446744073709551615) as u64)
    }
    
    public fun is_ask(arg0: u128) : bool {
        arg0 < 170141183460469231731687303715884105728
    }
    
    public fun order_id_ask(arg0: u64, arg1: u64) : u128 {
        assert!(arg0 < 9223372036854775808, perpetual_v3::errors::invalid_size_or_price());
        (arg0 as u128) << 64 | (arg1 as u128)
    }
    
    public fun order_id_bid(arg0: u64, arg1: u64) : u128 {
        assert!(arg0 < 9223372036854775808, perpetual_v3::errors::invalid_size_or_price());
        ((arg0 ^ 18446744073709551615) as u128) << 64 | (arg1 as u128)
    }
    
    public fun price(arg0: u128) : u64 {
        if (is_ask(arg0)) {
            price_ask(arg0)
        } else {
            price_bid(arg0)
        }
    }
    
    public fun price_ask(arg0: u128) : u64 {
        ((arg0 >> 64) as u64)
    }
    
    public fun price_bid(arg0: u128) : u64 {
        ((arg0 >> 64) as u64) ^ 18446744073709551615
    }
    
    // decompiled from Move bytecode v6
}

