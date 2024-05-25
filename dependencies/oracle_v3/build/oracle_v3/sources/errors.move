module oracle_v3::errors {
    /* friend oracle_v3::events; */
    /* friend oracle_v3::keys; */

    public fun invalid_price_value() : u64 {
        5
    }
    
    public fun invalid_source_object_for_feed() : u64 {
        3
    }
    
    public fun price_feed_already_exists() : u64 {
        1
    }
    
    public fun price_feed_does_not_exist() : u64 {
        2
    }
    
    public fun price_is_too_high() : u64 {
        10
    }
    
    public fun price_timestamp_is_incorrect() : u64 {
        4
    }
    
    public fun source_already_authorized() : u64 {
        6
    }
    
    public fun source_not_authorized() : u64 {
        7
    }
    
    public fun source_object_is_not_registered() : u64 {
        8
    }
    
    public fun symbol_does_not_exists() : u64 {
        9
    }
    
    public fun time_tolerance_too_high() : u64 {
        11
    }
    
    // decompiled from Move bytecode v6
}

