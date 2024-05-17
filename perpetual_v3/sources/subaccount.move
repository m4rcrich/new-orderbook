#[allow(unused_variable)]
module perpetual_v3::subaccount {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};
    friend perpetual_v3::admin;
    friend perpetual_v3::clearing_house;
    friend perpetual_v3::constants;
    friend perpetual_v3::interface;
    friend perpetual_v3::orderbook;
    friend perpetual_v3::ordered_map;
    friend perpetual_v3::position;
    friend perpetual_v3::registry;

    struct SubAccount<phantom T0> has store, key {
        id: sui::object::UID,
        user: address,
        account_id: u64,
        collateral: sui::balance::Balance<T0>,
    }
    
    public fun get_account_id<T0>(arg0: &SubAccount<T0>) : u64 {
        arg0.account_id
    }
    
    public(friend) fun create_subaccount<T0>(arg0: &perpetual_v3::account::Account<T0>, arg1: address, arg2: &mut sui::tx_context::TxContext) {
        let v0 = perpetual_v3::account::get_account_id<T0>(arg0);
        let v1 = SubAccount<T0>{
            id         : sui::object::new(arg2), 
            user       : arg1, 
            account_id : v0, 
            collateral : sui::balance::zero<T0>(),
        };
        sui::transfer::public_share_object<SubAccount<T0>>(v1);
        perpetual_v3::events::emit_created_subaccount(sui::object::id<SubAccount<T0>>(&v1), arg1, v0);
    }
    
    public(friend) fun delete_subaccount<T0>(arg0: &perpetual_v3::account::Account<T0>, arg1: SubAccount<T0>) {
        perpetual_v3::events::emit_deleted_subaccount(sui::object::id<SubAccount<T0>>(&arg1), perpetual_v3::account::get_account_id<T0>(arg0));
        let SubAccount {
            id         : v0,
            user       : _,
            account_id : v2,
            collateral : v3,
        } = arg1;
        let v4 = v3;
        assert!(perpetual_v3::account::get_account_id<T0>(arg0) == v2, perpetual_v3::errors::wrong_parent_for_subaccount());
        assert!(sui::balance::value<T0>(&v4) == 0, perpetual_v3::errors::subaccount_contains_collateral());
        sui::balance::destroy_zero<T0>(v4);
        sui::object::delete(v0);
    }
    
    public(friend) fun deposit_collateral<T0>(arg0: &mut SubAccount<T0>, arg1: sui::coin::Coin<T0>) {
        let v0 = sui::coin::value<T0>(&arg1);
        assert!(v0 != 0, perpetual_v3::errors::deposit_or_withdraw_amount_zero());
        sui::balance::join<T0>(&mut arg0.collateral, sui::coin::into_balance<T0>(arg1));
        perpetual_v3::events::emit_deposited_collateral_subaccount(sui::object::id<SubAccount<T0>>(arg0), arg0.account_id, v0, get_collateral_value<T0>(arg0));
    }
    
    public(friend) fun get_collateral_mut<T0>(arg0: &mut SubAccount<T0>) : &mut sui::balance::Balance<T0> {
        &mut arg0.collateral
    }
    
    public fun get_collateral_value<T0>(arg0: &SubAccount<T0>) : u64 {
        sui::balance::value<T0>(&arg0.collateral)
    }
    
    public fun get_subaccount_user<T0>(arg0: &SubAccount<T0>) : address {
        arg0.user
    }
    
    public(friend) fun set_subaccount_user<T0>(arg0: &perpetual_v3::account::Account<T0>, arg1: &mut SubAccount<T0>, arg2: address) {
        assert!(perpetual_v3::account::get_account_id<T0>(arg0) == arg1.account_id, perpetual_v3::errors::wrong_parent_for_subaccount());
        arg1.user = arg2;
        perpetual_v3::events::emit_set_subaccount_user(sui::object::id<SubAccount<T0>>(arg1), arg2, arg1.account_id);
    }
    
    public(friend) fun withdraw_collateral<T0>(arg0: &perpetual_v3::account::Account<T0>, arg1: &mut SubAccount<T0>, arg2: u64, arg3: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        assert!(perpetual_v3::account::get_account_id<T0>(arg0) == arg1.account_id, perpetual_v3::errors::wrong_parent_for_subaccount());
        assert!(arg2 != 0, perpetual_v3::errors::deposit_or_withdraw_amount_zero());
        perpetual_v3::events::emit_withdrew_collateral_subaccount(sui::object::id<SubAccount<T0>>(arg1), arg1.account_id, arg2, get_collateral_value<T0>(arg1));
        sui::coin::take<T0>(&mut arg1.collateral, arg2, arg3)
    }
    
    // decompiled from Move bytecode v6
}

