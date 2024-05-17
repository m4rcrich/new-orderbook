#[allow(unused_variable)]
module perpetual_v3::constants {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};

    public fun ask() : bool {
        true
    }
    
    public fun b9_scaling() : u256 {
        1000000000
    }
    
    public fun bid() : bool {
        false
    }
    
    public fun fill_or_kill() : u64 {
        1
    }
    
    public fun immediate_or_cancel() : u64 {
        3
    }
    
    public fun insurance_open_interest_fraction() : u256 {
        ifixed_v3::ifixed::from_u64fraction(500, 10000)
    }
    
    public fun low_min_order_usd_value() : u256 {
        ifixed_v3::ifixed::from_u64fraction(50, 100)
    }
    
    public fun max_abs_maker_fee() : u256 {
        ifixed_v3::ifixed::from_u64fraction(500, 10000)
    }
    
    public fun max_abs_taker_fee() : u256 {
        ifixed_v3::ifixed::from_u64fraction(500, 10000)
    }
    
    public fun max_book_index_spread_percent() : u64 {
        5
    }
    
    public fun max_force_cancel_fee() : u256 {
        ifixed_v3::ifixed::from_u64fraction(500, 10000)
    }
    
    public fun max_funding_period_ms() : u64 {
        129600000
    }
    
    public fun max_insurance_fund_fee() : u256 {
        ifixed_v3::ifixed::from_u64fraction(500, 10000)
    }
    
    public fun max_liquidation_fee() : u256 {
        ifixed_v3::ifixed::from_u64fraction(500, 10000)
    }
    
    public fun max_liquidation_tolerance() : u64 {
        300
    }
    
    public fun max_proposal_delay_ms() : u64 {
        259200000
    }
    
    public fun min_funding_frequency_ms() : u64 {
        60000
    }
    
    public fun min_funding_period_ms() : u64 {
        21600000
    }
    
    public fun min_liquidation_tolerance() : u64 {
        1
    }
    
    public fun min_oracle_tolerance() : u64 {
        10000
    }
    
    public fun min_premium_twap_frequency_ms() : u64 {
        1000
    }
    
    public fun min_premium_twap_period_ms() : u64 {
        60000
    }
    
    public fun min_proposal_delay_ms() : u64 {
        86400000
    }
    
    public fun min_spread_twap_frequency_ms() : u64 {
        1000
    }
    
    public fun min_spread_twap_period_ms() : u64 {
        60000
    }
    
    public fun null_fee() : u256 {
        1000000000000000000
    }
    
    public fun one_b9() : u64 {
        1000000000
    }
    
    public fun one_fixed() : u256 {
        1000000000000000000
    }
    
    public fun order_types() : u64 {
        4
    }
    
    public fun post_only() : u64 {
        2
    }
    
    public fun standard_order() : u64 {
        0
    }
    
    public fun up_max_pending_orders() : u64 {
        100
    }
    
    public fun up_min_order_usd_value() : u256 {
        ifixed_v3::ifixed::from_u64fraction(100000, 100)
    }
    
    public fun version() : u64 {
        0
    }
    
    // decompiled from Move bytecode v6
}

