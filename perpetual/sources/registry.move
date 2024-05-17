#[allow(unused_variable)]
module perpetual_v3::registry {
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
    friend perpetual_v3::orderbook;
    friend perpetual_v3::ordered_map;
    friend perpetual_v3::position;
    friend perpetual_v3::subaccount;

    struct Registry has key {
        id: sui::object::UID,
        next_account_id: u64,
    }
    
    fun get_collateral_symbol<T0>() : std::string::String {
        std::string::utf8(std::ascii::into_bytes(std::type_name::into_string(std::type_name::get<T0>())))
    }
    
    public(friend) fun inc_account_id(arg0: &mut Registry) : u64 {
        let v0 = arg0.next_account_id;
        arg0.next_account_id = v0 + 1;
        v0
    }
    
    fun init(arg0: &mut sui::tx_context::TxContext) {
        let v0 = Registry{
            id              : sui::object::new(arg0), 
            next_account_id : 0,
        };
        sui::transfer::share_object<Registry>(v0);
    }
    
    public(friend) fun register_market<T0>(arg0: &mut Registry, arg1: u64, arg2: sui::object::ID) {
        assert!(!sui::dynamic_field::exists_<perpetual_v3::keys::Registry>(&arg0.id, perpetual_v3::keys::registry(arg1)), perpetual_v3::errors::market_id_already_used());
        sui::dynamic_field::add<perpetual_v3::keys::Registry, sui::object::ID>(&mut arg0.id, perpetual_v3::keys::registry(arg1), arg2);
        perpetual_v3::events::emit_registered_clearing_house(arg1, arg2, get_collateral_symbol<T0>());
    }
    
    // decompiled from Move bytecode v6
}

