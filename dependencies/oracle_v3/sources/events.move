module oracle_v3::events {
    /* friend oracle_v3::errors; */
    /* friend oracle_v3::keys; */

    public struct CreatedPriceFeedStorage has copy, drop {
        price_feed_storage_id: sui::object::ID,
        symbol: std::string::String,
        decimals: u64,
    }
    
    public struct AddedAuthorization has copy, drop {
        source_wrapper_id: sui::object::ID,
    }
    
    public struct RemovedAuthorization has copy, drop {
        source_wrapper_id: sui::object::ID,
    }
    
    public struct CreatedPriceFeed has copy, drop {
        price_feed_storage_id: sui::object::ID,
        source_wrapper_id: sui::object::ID,
        price: u256,
        timestamp: u64,
        time_tolerance: u64,
    }
    
    public struct RemovedPriceFeed has copy, drop {
        price_feed_storage_id: sui::object::ID,
        source_wrapper_id: sui::object::ID,
    }
    
    public struct UpdatedPriceFeed has copy, drop {
        price_feed_storage_id: sui::object::ID,
        source_wrapper_id: sui::object::ID,
        old_price: u256,
        old_timestamp: u64,
        new_price: u256,
        new_timestamp: u64,
    }
    
    public struct UpdatedPriceFeedTimeTolerance has copy, drop {
        price_feed_storage_id: sui::object::ID,
        source_wrapper_id: sui::object::ID,
        old_time_tolerance: u64,
        new_time_tolerance: u64,
    }
    
    public(package) fun emit_added_authorization(arg0: sui::object::ID) {
        let v0 = AddedAuthorization{source_wrapper_id: arg0};
        sui::event::emit<AddedAuthorization>(v0);
    }
    
    public(package) fun emit_created_price_feed(arg0: sui::object::ID, arg1: sui::object::ID, arg2: u256, arg3: u64, arg4: u64) {
        let v0 = CreatedPriceFeed{
            price_feed_storage_id : arg0, 
            source_wrapper_id     : arg1, 
            price                 : arg2, 
            timestamp             : arg3, 
            time_tolerance        : arg4,
        };
        sui::event::emit<CreatedPriceFeed>(v0);
    }
    
    public(package) fun emit_created_price_feed_storage(arg0: sui::object::ID, arg1: std::string::String, arg2: u64) {
        let v0 = CreatedPriceFeedStorage{
            price_feed_storage_id : arg0, 
            symbol                : arg1, 
            decimals              : arg2,
        };
        sui::event::emit<CreatedPriceFeedStorage>(v0);
    }
    
    public(package) fun emit_removed_authorization(arg0: sui::object::ID) {
        let v0 = RemovedAuthorization{source_wrapper_id: arg0};
        sui::event::emit<RemovedAuthorization>(v0);
    }
    
    public(package) fun emit_removed_price_feed(arg0: sui::object::ID, arg1: sui::object::ID) {
        let v0 = RemovedPriceFeed{
            price_feed_storage_id : arg0, 
            source_wrapper_id     : arg1,
        };
        sui::event::emit<RemovedPriceFeed>(v0);
    }
    
    public(package) fun emit_updated_price_feed(arg0: sui::object::ID, arg1: sui::object::ID, arg2: u256, arg3: u64, arg4: u256, arg5: u64) {
        let v0 = UpdatedPriceFeed{
            price_feed_storage_id : arg0, 
            source_wrapper_id     : arg1, 
            old_price             : arg2, 
            old_timestamp         : arg3, 
            new_price             : arg4, 
            new_timestamp         : arg5,
        };
        sui::event::emit<UpdatedPriceFeed>(v0);
    }
    
    public(package) fun emit_updated_price_feed_time_tolerance(arg0: sui::object::ID, arg1: sui::object::ID, arg2: u64, arg3: u64) {
        let v0 = UpdatedPriceFeedTimeTolerance{
            price_feed_storage_id : arg0, 
            source_wrapper_id     : arg1, 
            old_time_tolerance    : arg2, 
            new_time_tolerance    : arg3,
        };
        sui::event::emit<UpdatedPriceFeedTimeTolerance>(v0);
    }
    
    // decompiled from Move bytecode v6
}

