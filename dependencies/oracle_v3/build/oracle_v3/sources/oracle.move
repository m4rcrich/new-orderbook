module oracle_v3::oracle {
    /* friend oracle_v3::errors; */
    /* friend oracle_v3::events; */
    /* friend oracle_v3::keys; */

    public struct AuthorityCap has store, key {
        id: sui::object::UID,
    }
    
    public struct PriceFeedStorage has store, key {
        id: sui::object::UID,
        symbol: std::string::String,
        feeds: sui::linked_table::LinkedTable<oracle_v3::keys::PriceFeedForSource, PriceFeed>,
        decimals: u64,
    }
    
    public struct PriceFeed has store, key {
        id: sui::object::UID,
        price: u256,
        timestamp: u64,
        time_tolerance: u64,
    }
    
    public struct SourceCap has store {
        dummy_field: bool,
    }
    
    public fun add_authorization(arg0: &AuthorityCap, arg1: &mut sui::object::UID) {
        assert!(!is_authorized(arg1), oracle_v3::errors::source_already_authorized());
        let v0 = SourceCap{dummy_field: false};
        sui::dynamic_field::add<oracle_v3::keys::Authorization, SourceCap>(arg1, oracle_v3::keys::authorization(), v0);
        oracle_v3::events::emit_added_authorization(sui::object::uid_to_inner(arg1));
    }
    
    public fun any_source(arg0: &PriceFeedStorage) : bool {
        !sui::linked_table::is_empty<oracle_v3::keys::PriceFeedForSource, PriceFeed>(&arg0.feeds)
    }
    
    fun assert_authorized(arg0: &sui::object::UID) {
        assert!(is_authorized(arg0), oracle_v3::errors::source_not_authorized());
    }
    
    public fun create_price_feed(arg0: &AuthorityCap, arg1: &sui::clock::Clock, arg2: &mut PriceFeedStorage, arg3: &sui::object::UID, arg4: u256, arg5: u64, arg6: u64, arg7: &mut sui::tx_context::TxContext) {
        assert_authorized(arg3);
        assert!(!ifixed_v3::ifixed::is_neg(arg4), oracle_v3::errors::price_is_too_high());
        let v0 = sui::clock::timestamp_ms(arg1);
        assert!(v0 >= arg5 && v0 - arg5 <= arg6, oracle_v3::errors::price_timestamp_is_incorrect());
        create_price_feed_inner(arg2, arg3, arg4, arg5, arg6, arg7);
        oracle_v3::events::emit_created_price_feed(sui::object::id<PriceFeedStorage>(arg2), *sui::object::uid_as_inner(arg3), arg4, arg5, arg6);
    }
    
    fun create_price_feed_inner(arg0: &mut PriceFeedStorage, arg1: &sui::object::UID, arg2: u256, arg3: u64, arg4: u64, arg5: &mut sui::tx_context::TxContext) {
        let v0 = sui::object::uid_to_inner(arg1);
        assert!(!exists_price_feed(arg0, v0), oracle_v3::errors::price_feed_already_exists());
        let v1 = PriceFeed{
            id             : sui::object::new(arg5), 
            price          : arg2, 
            timestamp      : arg3, 
            time_tolerance : arg4,
        };
        sui::linked_table::push_back<oracle_v3::keys::PriceFeedForSource, PriceFeed>(&mut arg0.feeds, oracle_v3::keys::price_feed_for_source(v0), v1);
    }
    
    public fun create_price_feed_storage(arg0: &AuthorityCap, arg1: std::string::String, arg2: u64, arg3: &mut sui::tx_context::TxContext) {
        let v0 = PriceFeedStorage{
            id       : sui::object::new(arg3), 
            symbol   : arg1, 
            feeds    : sui::linked_table::new<oracle_v3::keys::PriceFeedForSource, PriceFeed>(arg3), 
            decimals : arg2,
        };
        oracle_v3::events::emit_created_price_feed_storage(sui::object::id<PriceFeedStorage>(&v0), arg1, arg2);
        sui::transfer::share_object<PriceFeedStorage>(v0);
    }
    
    public fun exists_price_feed(arg0: &PriceFeedStorage, arg1: sui::object::ID) : bool {
        sui::linked_table::contains<oracle_v3::keys::PriceFeedForSource, PriceFeed>(&arg0.feeds, oracle_v3::keys::price_feed_for_source(arg1))
    }
    
    public fun get_decimals(arg0: &PriceFeedStorage) : u64 {
        arg0.decimals
    }
    
    public fun get_feeds(arg0: &PriceFeedStorage) : &sui::linked_table::LinkedTable<oracle_v3::keys::PriceFeedForSource, PriceFeed> {
        &arg0.feeds
    }
    
    public fun get_price(arg0: &PriceFeed) : u256 {
        arg0.price
    }
    
    public fun get_price_and_timestamp(arg0: &PriceFeed) : (u256, u64) {
        (arg0.price, arg0.timestamp)
    }
    
    public fun get_price_feed(arg0: &PriceFeedStorage, arg1: sui::object::ID) : &PriceFeed {
        assert!(exists_price_feed(arg0, arg1), oracle_v3::errors::price_feed_does_not_exist());
        sui::linked_table::borrow<oracle_v3::keys::PriceFeedForSource, PriceFeed>(&arg0.feeds, oracle_v3::keys::price_feed_for_source(arg1))
    }
    
    fun get_price_feed_mut(arg0: &mut PriceFeedStorage, arg1: sui::object::ID) : &mut PriceFeed {
        assert!(exists_price_feed(arg0, arg1), oracle_v3::errors::price_feed_does_not_exist());
        sui::linked_table::borrow_mut<oracle_v3::keys::PriceFeedForSource, PriceFeed>(&mut arg0.feeds, oracle_v3::keys::price_feed_for_source(arg1))
    }
    
    public fun get_price_feed_uid_mut(arg0: &mut PriceFeedStorage, arg1: &sui::object::UID) : &mut sui::object::UID {
        assert_authorized(arg1);
        &mut get_price_feed_mut(arg0, sui::object::uid_to_inner(arg1)).id
    }
    
    public fun get_price_of_unit(arg0: &PriceFeedStorage, arg1: &PriceFeed) : u256 {
        ifixed_v3::ifixed::div(arg1.price, ifixed_v3::ifixed::from_u64(arg0.decimals))
    }
    
    public fun get_symbol(arg0: &PriceFeedStorage) : std::string::String {
        arg0.symbol
    }
    
    public fun get_time_tolerance(arg0: &PriceFeed) : u64 {
        arg0.time_tolerance
    }
    
    fun init(arg0: &mut sui::tx_context::TxContext) {
        let v0 = AuthorityCap{id: sui::object::new(arg0)};
        sui::transfer::transfer<AuthorityCap>(v0, sui::tx_context::sender(arg0));
    }
    
    public fun is_authorized(arg0: &sui::object::UID) : bool {
        sui::dynamic_field::exists_<oracle_v3::keys::Authorization>(arg0, oracle_v3::keys::authorization())
    }
    
    public fun remove_authorization(arg0: &AuthorityCap, arg1: &mut sui::object::UID) {
        assert_authorized(arg1);
        let SourceCap { dummy_field } = sui::dynamic_field::remove<oracle_v3::keys::Authorization, SourceCap>(arg1, oracle_v3::keys::authorization());
        oracle_v3::events::emit_removed_authorization(sui::object::uid_to_inner(arg1));
    }
    
    public fun remove_price_feed(arg0: &AuthorityCap, arg1: &mut PriceFeedStorage, arg2: sui::object::ID) {
        assert!(exists_price_feed(arg1, arg2), oracle_v3::errors::price_feed_does_not_exist());
        let PriceFeed {
            id             : v0,
            price          : _,
            timestamp      : _,
            time_tolerance : _,
        } = sui::linked_table::remove<oracle_v3::keys::PriceFeedForSource, PriceFeed>(&mut arg1.feeds, oracle_v3::keys::price_feed_for_source(arg2));
        sui::object::delete(v0);
        oracle_v3::events::emit_removed_price_feed(sui::object::id<PriceFeedStorage>(arg1), arg2);
    }
    
    public fun update_decimals_info(arg0: &AuthorityCap, arg1: &mut PriceFeedStorage, arg2: u64) {
        arg1.decimals = arg2;
    }
    
    public fun update_price_feed(arg0: &sui::clock::Clock, arg1: &mut PriceFeedStorage, arg2: &sui::object::UID, arg3: u256, arg4: u64) {
        assert_authorized(arg2);
        assert!(!ifixed_v3::ifixed::is_neg(arg3), oracle_v3::errors::price_is_too_high());
        let (v0, v1) = update_price_feed_inner(arg0, arg1, arg2, arg3, arg4);
        oracle_v3::events::emit_updated_price_feed(sui::object::id<PriceFeedStorage>(arg1), *sui::object::uid_as_inner(arg2), v0, v1, arg3, arg4);
    }
    
    fun update_price_feed_inner(arg0: &sui::clock::Clock, arg1: &mut PriceFeedStorage, arg2: &sui::object::UID, arg3: u256, arg4: u64) : (u256, u64) {
        let v0 = get_price_feed_mut(arg1, sui::object::uid_to_inner(arg2));
        let v1 = sui::clock::timestamp_ms(arg0);
        assert!(v1 >= arg4 && arg4 > v0.timestamp && v1 - arg4 <= v0.time_tolerance, oracle_v3::errors::price_timestamp_is_incorrect());
        v0.price = arg3;
        v0.timestamp = arg4;
        (v0.price, v0.timestamp)
    }
    
    public fun update_price_feed_time_tolerance(arg0: &AuthorityCap, arg1: &mut PriceFeedStorage, arg2: &sui::object::UID, arg3: u64) {
        assert_authorized(arg2);
        let v0 = sui::object::uid_to_inner(arg2);
        let id = sui::object::id<PriceFeedStorage>(arg1);
        let v1 = get_price_feed_mut(arg1, v0);
        v1.time_tolerance = arg3;
        oracle_v3::events::emit_updated_price_feed_time_tolerance(id, v0, arg3, arg3);
    }
    
    // decompiled from Move bytecode v6
}

