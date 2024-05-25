module oracle_reader_v3::oracle_reader {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};
    
    public fun get_average_price_for_all_sources(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: &sui::clock::Clock, arg2: u64, arg3: bool, arg4: bool) : u256 {
        let v0 = oracle_v3::oracle::get_feeds(arg0);
        let mut v1 = sui::linked_table::front<oracle_v3::keys::PriceFeedForSource, oracle_v3::oracle::PriceFeed>(v0);
        let v2 = sui::clock::timestamp_ms(arg1);
        let mut v3 = 0;
        let mut v4 = 0;
        while (!std::option::is_none<oracle_v3::keys::PriceFeedForSource>(v1)) {
            let v5 = *std::option::borrow<oracle_v3::keys::PriceFeedForSource>(v1);
            let (v6, v7) = oracle_v3::oracle::get_price_and_timestamp(sui::linked_table::borrow<oracle_v3::keys::PriceFeedForSource, oracle_v3::oracle::PriceFeed>(v0, v5));
            if (v7 >= v2 - sui::math::min(v2, arg2) && v7 <= v2) {
                v3 = v3 + v6;
                v4 = v4 + 1;
            };
            v1 = sui::linked_table::next<oracle_v3::keys::PriceFeedForSource, oracle_v3::oracle::PriceFeed>(v0, v5);
        };
        if (arg3) {
            v3 = price_of_unit(arg0, v3);
        };
        if (v4 == 0 && arg4) {
            abort 1
        };
        ifixed_v3::ifixed::div(v3, ifixed_v3::ifixed::from_u64(sui::math::max(v4, 1)))
    }
    
    public fun get_average_price_for_sources(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: &sui::clock::Clock, arg2: vector<sui::object::ID>, arg3: u64, arg4: bool, arg5: bool) : u256 {
        let v0 = std::vector::length<sui::object::ID>(&arg2);
        assert!(v0 != 0, 0);
        let v1 = sui::clock::timestamp_ms(arg1);
        let mut v2 = 0;
        let mut v3 = 0;
        let mut v4 = 0;
        while (v4 < v0) {
            let v5 = *std::vector::borrow<sui::object::ID>(&arg2, v4);
            v4 = v4 + 1;
            let (v6, v7) = oracle_v3::oracle::get_price_and_timestamp(oracle_v3::oracle::get_price_feed(arg0, v5));
            if (v7 >= v1 - sui::math::min(v1, arg3) && v7 <= v1) {
                v2 = v2 + v6;
                v3 = v3 + 1;
                continue
            };
        };
        if (arg4) {
            v2 = price_of_unit(arg0, v2);
        };
        if (v3 == 0 && arg5) {
            abort 1
        };
        ifixed_v3::ifixed::div(v2, ifixed_v3::ifixed::from_u64(sui::math::max(v3, 1)))
    }
    
    public fun get_average_reciprocal_price_for_all_sources(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: &sui::clock::Clock, arg2: u64, arg3: bool, arg4: bool) : u256 {
        let v0 = oracle_v3::oracle::get_feeds(arg0);
        let mut v1 = sui::linked_table::front<oracle_v3::keys::PriceFeedForSource, oracle_v3::oracle::PriceFeed>(v0);
        let v2 = sui::clock::timestamp_ms(arg1);
        let mut v3 = 0;
        let mut v4 = 0;
        while (!std::option::is_none<oracle_v3::keys::PriceFeedForSource>(v1)) {
            let v5 = *std::option::borrow<oracle_v3::keys::PriceFeedForSource>(v1);
            let (v6, v7) = oracle_v3::oracle::get_price_and_timestamp(sui::linked_table::borrow<oracle_v3::keys::PriceFeedForSource, oracle_v3::oracle::PriceFeed>(v0, v5));
            if (v7 >= v2 - sui::math::min(v2, arg2) && v7 <= v2) {
                v3 = v3 + ifixed_v3::ifixed::div(ifixed_v3::ifixed::from_u64(1), v6);
                v4 = v4 + 1;
            };
            v1 = sui::linked_table::next<oracle_v3::keys::PriceFeedForSource, oracle_v3::oracle::PriceFeed>(v0, v5);
        };
        if (arg3) {
            v3 = price_in_units(arg0, v3);
        };
        if (v4 == 0 && arg4) {
            abort 1
        };
        ifixed_v3::ifixed::div(v3, ifixed_v3::ifixed::from_u64(sui::math::max(v4, 1)))
    }
    
    public fun get_average_reciprocal_price_for_sources(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: &sui::clock::Clock, arg2: vector<sui::object::ID>, arg3: u64, arg4: bool, arg5: bool) : u256 {
        let v0 = std::vector::length<sui::object::ID>(&arg2);
        assert!(v0 != 0, 0);
        let v1 = sui::clock::timestamp_ms(arg1);
        let mut v2 = 0;
        let mut v3 = 0;
        let mut v4 = 0;
        while (v4 < v0) {
            let v5 = *std::vector::borrow<sui::object::ID>(&arg2, v4);
            v4 = v4 + 1;
            let (v6, v7) = oracle_v3::oracle::get_price_and_timestamp(oracle_v3::oracle::get_price_feed(arg0, v5));
            if (v7 >= v1 - sui::math::min(v1, arg3) && v7 <= v1) {
                v2 = v2 + ifixed_v3::ifixed::div(ifixed_v3::ifixed::from_u64(1), v6);
                v3 = v3 + 1;
                continue
            };
        };
        if (arg4) {
            v2 = price_in_units(arg0, v2);
        };
        if (v3 == 0 && arg5) {
            abort 1
        };
        ifixed_v3::ifixed::div(v2, ifixed_v3::ifixed::from_u64(sui::math::max(v3, 1)))
    }
    
    public fun get_median_price_for_all_sources(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: &sui::clock::Clock, arg2: u64) : u256 {
        let v0 = get_valid_prices_for_feeds(arg0, arg1, arg2);
        let v1 = std::vector::length<u256>(&v0);
        if (v1 == 1) {
            *std::vector::borrow<u256>(&v0, 0)
        } else {
            let v3 = if (v1 == 2) {
                ifixed_v3::ifixed::max(*std::vector::borrow<u256>(&v0, 0), *std::vector::borrow<u256>(&v0, 1))
            } else {
                let v4 = if (v1 == 3) {
                    median(*std::vector::borrow<u256>(&v0, 0), *std::vector::borrow<u256>(&v0, 1), *std::vector::borrow<u256>(&v0, 2))
                } else {
                    assert!(v1 != 0, 1);
                    assert!(v1 < 4, 2);
                    0
                };
                v4
            };
            v3
        }
    }
    
    public fun get_price_and_timestamp_for_source(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: sui::object::ID) : (u256, u64) {
        oracle_v3::oracle::get_price_and_timestamp(oracle_v3::oracle::get_price_feed(arg0, arg1))
    }
    
    public fun get_price_for_source(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: sui::object::ID, arg2: bool) : u256 {
        let v0 = oracle_v3::oracle::get_price(oracle_v3::oracle::get_price_feed(arg0, arg1));
        let mut v1 = v0;
        if (arg2) {
            v1 = price_of_unit(arg0, v0);
        };
        v1
    }
    
    public fun get_timestamp_for_source(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: sui::object::ID) : u64 {
        let (_, v1) = oracle_v3::oracle::get_price_and_timestamp(oracle_v3::oracle::get_price_feed(arg0, arg1));
        v1
    }
    
    fun get_valid_prices_for_feeds(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: &sui::clock::Clock, arg2: u64) : vector<u256> {
        let v0 = sui::clock::timestamp_ms(arg1);
        let v1 = oracle_v3::oracle::get_feeds(arg0);
        let mut v2 = sui::linked_table::front<oracle_v3::keys::PriceFeedForSource, oracle_v3::oracle::PriceFeed>(v1);
        let mut v3 = std::vector::empty<u256>();
        while (!std::option::is_none<oracle_v3::keys::PriceFeedForSource>(v2)) {
            let v4 = *std::option::borrow<oracle_v3::keys::PriceFeedForSource>(v2);
            let (v5, v6) = oracle_v3::oracle::get_price_and_timestamp(sui::linked_table::borrow<oracle_v3::keys::PriceFeedForSource, oracle_v3::oracle::PriceFeed>(v1, v4));
            if (v6 >= v0 - sui::math::min(v0, arg2) && v6 <= v0 && v5 != 0 && v5 < ifixed_v3::ifixed::max_value()) {
                std::vector::push_back<u256>(&mut v3, v5);
            };
            v2 = sui::linked_table::next<oracle_v3::keys::PriceFeedForSource, oracle_v3::oracle::PriceFeed>(v1, v4);
        };
        v3
    }
    
    fun median(arg0: u256, arg1: u256, arg2: u256) : u256 {
        ifixed_v3::ifixed::max(ifixed_v3::ifixed::min(arg0, arg1), ifixed_v3::ifixed::min(ifixed_v3::ifixed::max(arg0, arg1), arg2))
    }
    
    public fun price_in_units(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: u256) : u256 {
        ifixed_v3::ifixed::mul(arg1, ifixed_v3::ifixed::from_u64(oracle_v3::oracle::get_decimals(arg0)))
    }
    
    public fun price_of_unit(arg0: &oracle_v3::oracle::PriceFeedStorage, arg1: u256) : u256 {
        ifixed_v3::ifixed::div(arg1, ifixed_v3::ifixed::from_u64(oracle_v3::oracle::get_decimals(arg0)))
    }
    
    // decompiled from Move bytecode v6
}

