#[allow(unused_variable)]
module perpetual_v3::admin {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};
    friend perpetual_v3::clearing_house;

    struct AdminCapability has store, key {
        id: sui::object::UID,
    }
    
    fun init(arg0: &mut sui::tx_context::TxContext) {
        let v0 = AdminCapability{id: sui::object::new(arg0)};
        sui::transfer::transfer<AdminCapability>(v0, sui::tx_context::sender(arg0));
    }
    
    // decompiled from Move bytecode v6
}

