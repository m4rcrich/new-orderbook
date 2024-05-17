#[allow(unused_variable)]
module perpetual_v3::errors {
    
    public fun bad_index_price() : u64 {
        2
    }
    
    public fun deposit_or_withdraw_amount_zero() : u64 {
        0
    }
    
    public fun destroy_not_empty() : u64 {
        3003
    }
    
    public fun empty_session() : u64 {
        17
    }
    
    public fun flag_requirements_violated() : u64 {
        3005
    }
    
    public fun initial_margin_requirements_violated() : u64 {
        2003
    }
    
    public fun insufficient_free_collateral() : u64 {
        2006
    }
    
    public fun insufficient_insurance_surplus() : u64 {
        1007
    }
    
    public fun invalid_cancel_order_ids() : u64 {
        7
    }
    
    public fun invalid_force_cancel_ids() : u64 {
        5
    }
    
    public fun invalid_map_parameters() : u64 {
        3000
    }
    
    public fun invalid_market_parameters() : u64 {
        1000
    }
    
    public fun invalid_price_feed_storage() : u64 {
        11
    }
    
    public fun invalid_proposal_delay() : u64 {
        1004
    }
    
    public fun invalid_size_or_price() : u64 {
        1
    }
    
    public fun invalid_subaccount_user() : u64 {
        13
    }
    
    public fun invalid_user_for_order() : u64 {
        3004
    }
    
    public fun key_already_exists() : u64 {
        3002
    }
    
    public fun key_not_exist() : u64 {
        3001
    }
    
    public fun liquidate_not_first_operation() : u64 {
        6
    }
    
    public fun map_too_small() : u64 {
        3007
    }
    
    public fun market_id_already_used() : u64 {
        3
    }
    
    public fun max_pending_orders_exceeded() : u64 {
        2000
    }
    
    public fun no_fees_accrued() : u64 {
        1006
    }
    
    public fun no_price_feed_for_market() : u64 {
        1008
    }
    
    public fun not_enough_liquidity() : u64 {
        3006
    }
    
    public fun order_usd_value_too_low() : u64 {
        4
    }
    
    public fun position_above_mmr() : u64 {
        2004
    }
    
    public fun position_above_tolerance() : u64 {
        2002
    }
    
    public fun position_already_exists() : u64 {
        2007
    }
    
    public fun position_bad_debt() : u64 {
        2005
    }
    
    public fun position_below_imr() : u64 {
        2001
    }
    
    public fun premature_proposal() : u64 {
        1003
    }
    
    public fun proposal_already_exists() : u64 {
        1002
    }
    
    public fun proposal_already_matured() : u64 {
        1009
    }
    
    public fun proposal_does_not_exist() : u64 {
        1005
    }
    
    public fun self_liquidation() : u64 {
        12
    }
    
    public fun self_trading() : u64 {
        3008
    }
    
    public fun stop_order_conditions_violated() : u64 {
        9
    }
    
    public fun stop_order_ticket_expired() : u64 {
        8
    }
    
    public fun subaccount_contains_collateral() : u64 {
        15
    }
    
    public fun updating_funding_too_early() : u64 {
        1001
    }
    
    public fun wrong_order_details() : u64 {
        10
    }
    
    public fun wrong_parent_for_subaccount() : u64 {
        14
    }
    
    public fun wrong_version() : u64 {
        16
    }
    
    // decompiled from Move bytecode v6
}

