module perpetual_v3::admin {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};
    friend perpetual_v3::account;
    friend perpetual_v3::clearing_house;
    friend perpetual_v3::constants;
    friend perpetual_v3::errors;
    friend perpetual_v3::events;
    friend perpetual_v3::interface;
    friend perpetual_v3::keys;
    friend perpetual_v3::market;
    friend perpetual_v3::oracle;
    friend perpetual_v3::order_id;
    friend perpetual_v3::orderbook;
    friend perpetual_v3::ordered_map;
    friend perpetual_v3::position;
    friend perpetual_v3::registry;
    friend perpetual_v3::subaccount;
    struct AdminCapability has store, key {
        id: sui::object::UID,
    }
    
    fun init(arg0: &mut sui::tx_context::TxContext) {
        let v0 = AdminCapability{id: sui::object::new(arg0)};
        sui::transfer::transfer<AdminCapability>(v0, sui::tx_context::sender(arg0));
    }
    
    // decompiled from Move bytecode v6
}

