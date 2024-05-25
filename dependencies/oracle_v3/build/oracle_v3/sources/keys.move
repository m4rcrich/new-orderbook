module oracle_v3::keys {
    /* friend oracle_v3::errors; */
    /* friend oracle_v3::events; */

    public struct PriceFeedForSource has copy, drop, store {
        source_wrapper_id: sui::object::ID,
    }
    
    public struct Authorization has copy, drop, store {
        dummy_field: bool,
    }
    
    public(package) fun authorization() : Authorization {
        Authorization{dummy_field: false}
    }
    
    public(package) fun price_feed_for_source(arg0: sui::object::ID) : PriceFeedForSource {
        PriceFeedForSource{source_wrapper_id: arg0}
    }
    
    // decompiled from Move bytecode v6
}

