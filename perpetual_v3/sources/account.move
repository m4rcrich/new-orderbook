#[allow(unused_variable)]
module perpetual_v3::account {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};
    friend perpetual_v3::errors;
    friend perpetual_v3::events;
    friend perpetual_v3::interface;
    friend perpetual_v3::clearing_house;
    friend perpetual_v3::registry;

    struct Account<phantom T0> has store, key {
        id: sui::object::UID,
        account_id: u64,
        collateral: sui::balance::Balance<T0>,
    }
    
    struct StopOrderTicket<phantom T0> has key {
        id: sui::object::UID,
        user_address: address,
        account_id: u64,
        encrypted_details: vector<u8>,
    }
    
    public(friend) fun create_account<T0>(arg0: &mut perpetual_v3::registry::Registry, arg1: &mut sui::tx_context::TxContext) : Account<T0> {
        let v0 = perpetual_v3::registry::inc_account_id(arg0);
        let v1 = Account<T0>{
            id         : sui::object::new(arg1), 
            account_id : v0, 
            collateral : sui::balance::zero<T0>(),
        };
        perpetual_v3::events::emit_created_account(sui::tx_context::sender(arg1), v0);
        v1
    }
    
    public(friend) fun create_stop_order_ticket<T0>(arg0: &Account<T0>, arg1: address, arg2: vector<u8>, arg3: &mut sui::tx_context::TxContext) {
        let v0 = StopOrderTicket<T0>{
            id                : sui::object::new(arg3), 
            user_address      : sui::tx_context::sender(arg3), 
            account_id        : arg0.account_id, 
            encrypted_details : arg2,
        };
        perpetual_v3::events::emit_created_stop_order_ticket(arg0.account_id, arg1, v0.encrypted_details);
        sui::transfer::transfer<StopOrderTicket<T0>>(v0, arg1);
    }
    
    public(friend) fun delete_stop_order_ticket<T0>(arg0: StopOrderTicket<T0>, arg1: bool) : (u64, vector<u8>) {
        let StopOrderTicket {
            id                : v0,
            user_address      : v1,
            account_id        : v2,
            encrypted_details : v3,
        } = arg0;
        let v4 = v0;
        perpetual_v3::events::emit_deleted_stop_order_ticket(sui::object::uid_to_inner(&v4), v1, arg1);
        sui::object::delete(v4);
        (v2, v3)
    }
    
    public(friend) fun deposit_collateral<T0>(arg0: &mut Account<T0>, arg1: sui::coin::Coin<T0>) {
        let v0 = sui::coin::value<T0>(&arg1);
        assert!(v0 != 0, perpetual_v3::errors::deposit_or_withdraw_amount_zero());
        sui::balance::join<T0>(&mut arg0.collateral, sui::coin::into_balance<T0>(arg1));
        perpetual_v3::events::emit_deposited_collateral(arg0.account_id, v0, get_collateral_value<T0>(arg0));
    }
    
    public fun get_account_id<T0>(arg0: &Account<T0>) : u64 {
        arg0.account_id
    }
    
    public(friend) fun get_collateral_mut<T0>(arg0: &mut Account<T0>) : &mut sui::balance::Balance<T0> {
        &mut arg0.collateral
    }
    
    public fun get_collateral_value<T0>(arg0: &Account<T0>) : u64 {
        sui::balance::value<T0>(&arg0.collateral)
    }
    
    public(friend) fun withdraw_collateral<T0>(arg0: &mut Account<T0>, arg1: u64, arg2: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        assert!(arg1 != 0, perpetual_v3::errors::deposit_or_withdraw_amount_zero());
        perpetual_v3::events::emit_withdrew_collateral(arg0.account_id, arg1, get_collateral_value<T0>(arg0));
        sui::coin::take<T0>(&mut arg0.collateral, arg1, arg2)
    }
    
    // decompiled from Move bytecode v6
}

