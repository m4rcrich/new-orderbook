module perpetual_v3::oracle {
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
    friend perpetual_v3::order_id;
    friend perpetual_v3::orderbook;
    friend perpetual_v3::ordered_map;
    friend perpetual_v3::position;
    friend perpetual_v3::registry;
    friend perpetual_v3::subaccount;

    public fun get_price(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: &sui::clock::Clock, arg2: u64) : u256 {
        oracle_reader_v3::oracle_reader::get_median_price_for_all_sources(arg0, arg1, arg2)
    }
    
    // decompiled from Move bytecode v6
}

