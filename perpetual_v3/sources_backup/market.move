module perpetual_v3::market {
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
    friend perpetual_v3::oracle;
    friend perpetual_v3::order_id;
    friend perpetual_v3::orderbook;
    friend perpetual_v3::ordered_map;
    friend perpetual_v3::position;
    friend perpetual_v3::registry;
    friend perpetual_v3::subaccount;

    struct MarketParams has copy, drop, store {
        margin_ratio_initial: u256,
        margin_ratio_maintenance: u256,
        base_pfs_id: sui::object::ID,
        collateral_pfs_id: sui::object::ID,
        funding_frequency_ms: u64,
        funding_period_ms: u64,
        premium_twap_frequency_ms: u64,
        premium_twap_period_ms: u64,
        spread_twap_frequency_ms: u64,
        spread_twap_period_ms: u64,
        maker_fee: u256,
        taker_fee: u256,
        liquidation_fee: u256,
        force_cancel_fee: u256,
        insurance_fund_fee: u256,
        min_order_usd_value: u256,
        lot_size: u64,
        tick_size: u64,
        liquidation_tolerance: u64,
        max_pending_orders: u64,
        oracle_tolerance: u64,
    }
    
    struct MarketState has store {
        cum_funding_rate_long: u256,
        cum_funding_rate_short: u256,
        funding_last_upd_ms: u64,
        premium_twap: u256,
        premium_twap_last_upd_ms: u64,
        spread_twap: u256,
        spread_twap_last_upd_ms: u64,
        open_interest: u256,
        fees_accrued: u256,
    }
    
    public(friend) fun add_fees_accrued_usd(arg0: &mut MarketState, arg1: u256, arg2: u256) {
        arg0.fees_accrued = ifixed_v3::ifixed::add(arg0.fees_accrued, ifixed_v3::ifixed::div(arg1, arg2));
    }
    
    public(friend) fun add_to_open_interest(arg0: &mut MarketState, arg1: u256) {
        arg0.open_interest = ifixed_v3::ifixed::add(arg0.open_interest, arg1);
    }
    
    public(friend) fun calculate_funding_price(arg0: &MarketState, arg1: &MarketParams, arg2: u256, arg3: u64) : u256 {
        ifixed_v3::ifixed::add(arg2, ifixed_v3::ifixed::mul(arg0.premium_twap, ifixed_v3::ifixed::from_u64fraction(sui::math::max(arg3, next_funding_update_time(arg0.funding_last_upd_ms, arg1.funding_frequency_ms)) - arg3, arg1.funding_period_ms)))
    }
    
    fun check_funding_parameters(arg0: u64, arg1: u64, arg2: u64, arg3: u64) {
        assert!(arg1 >= perpetual_v3::constants::min_funding_period_ms() && arg1 <= perpetual_v3::constants::max_funding_period_ms() && arg0 >= perpetual_v3::constants::min_funding_frequency_ms() && arg1 > arg0 && arg1 % arg0 == 0, perpetual_v3::errors::invalid_market_parameters());
        check_twap_parameters(arg2, arg3, perpetual_v3::constants::min_premium_twap_frequency_ms(), perpetual_v3::constants::min_premium_twap_period_ms());
    }
    
    fun check_liquidation_fees(arg0: u256, arg1: u256, arg2: u256) {
        assert!(!ifixed_v3::ifixed::is_neg(arg0) && ifixed_v3::ifixed::less_than_eq(arg0, perpetual_v3::constants::max_liquidation_fee()) && !ifixed_v3::ifixed::is_neg(arg1) && ifixed_v3::ifixed::less_than_eq(arg1, perpetual_v3::constants::max_force_cancel_fee()) && !ifixed_v3::ifixed::is_neg(arg2) && ifixed_v3::ifixed::less_than_eq(arg2, perpetual_v3::constants::max_insurance_fund_fee()), perpetual_v3::errors::invalid_market_parameters());
    }
    
    fun check_liquidation_tolerance(arg0: u64) {
        assert!(arg0 <= perpetual_v3::constants::max_liquidation_tolerance() && arg0 >= perpetual_v3::constants::min_liquidation_tolerance(), perpetual_v3::errors::invalid_market_parameters());
    }
    
    fun check_lot_and_tick_sizes(arg0: u64, arg1: u64) {
        assert!(arg0 <= perpetual_v3::constants::one_b9() && arg1 <= perpetual_v3::constants::one_b9(), perpetual_v3::errors::invalid_market_parameters());
    }
    
    public(friend) fun check_margin_ratios(arg0: u256, arg1: u256) {
        assert!(ifixed_v3::ifixed::less_than_eq(arg0, perpetual_v3::constants::one_fixed()) && ifixed_v3::ifixed::less_than(arg1, arg0) && ifixed_v3::ifixed::greater_than(arg1, 0), perpetual_v3::errors::invalid_market_parameters());
    }
    
    public(friend) fun check_market_fees(arg0: u256, arg1: u256) {
        assert!(ifixed_v3::ifixed::less_than_eq(ifixed_v3::ifixed::abs(arg0), perpetual_v3::constants::max_abs_maker_fee()) && ifixed_v3::ifixed::less_than_eq(ifixed_v3::ifixed::abs(arg1), perpetual_v3::constants::max_abs_taker_fee()), perpetual_v3::errors::invalid_market_parameters());
        let v0 = if (!ifixed_v3::ifixed::is_neg(arg0)) {
            true
        } else {
            let v1 = !ifixed_v3::ifixed::is_neg(arg1) && ifixed_v3::ifixed::less_than_eq(ifixed_v3::ifixed::abs(arg0), arg1);
            v1
        };
        assert!(v0, perpetual_v3::errors::invalid_market_parameters());
        let v2 = if (!ifixed_v3::ifixed::is_neg(arg1)) {
            true
        } else {
            let v3 = !ifixed_v3::ifixed::is_neg(arg0) && ifixed_v3::ifixed::less_than_eq(ifixed_v3::ifixed::abs(arg1), arg0);
            v3
        };
        assert!(v2, perpetual_v3::errors::invalid_market_parameters());
    }
    
    fun check_market_parameters(arg0: u256, arg1: u256, arg2: u64, arg3: u64, arg4: u64, arg5: u64, arg6: u64, arg7: u64, arg8: u256, arg9: u256, arg10: u256, arg11: u256, arg12: u256, arg13: u64, arg14: u64) {
        check_margin_ratios(arg0, arg1);
        check_funding_parameters(arg2, arg3, arg4, arg5);
        check_spread_twap_parameters(arg6, arg7);
        check_market_fees(arg8, arg9);
        check_liquidation_fees(arg10, arg11, arg12);
        check_lot_and_tick_sizes(arg13, arg14);
    }
    
    fun check_oracle_tolerance(arg0: u64) {
        assert!(arg0 >= perpetual_v3::constants::min_oracle_tolerance(), perpetual_v3::errors::invalid_market_parameters());
    }
    
    fun check_spread_twap_parameters(arg0: u64, arg1: u64) {
        check_twap_parameters(arg0, arg1, perpetual_v3::constants::min_spread_twap_frequency_ms(), perpetual_v3::constants::min_spread_twap_period_ms());
    }
    
    fun check_twap_parameters(arg0: u64, arg1: u64, arg2: u64, arg3: u64) {
        assert!(arg0 >= arg2 && arg1 >= arg3 && arg1 > arg0, perpetual_v3::errors::invalid_market_parameters());
    }
    
    fun clip_max_book_index_spread(arg0: u256, arg1: u256) : u256 {
        assert!(arg1 != 0, perpetual_v3::errors::bad_index_price());
        let v0 = ifixed_v3::ifixed::mul(arg1, ifixed_v3::ifixed::from_u64fraction(perpetual_v3::constants::max_book_index_spread_percent(), 100));
        let v1 = ifixed_v3::ifixed::add(arg1, v0);
        let v2 = ifixed_v3::ifixed::sub(arg1, v0);
        if (ifixed_v3::ifixed::greater_than(arg0, v1)) {
            v1
        } else {
            let v4 = if (ifixed_v3::ifixed::less_than(arg0, v2)) {
                v2
            } else {
                arg0
            };
            v4
        }
    }
    
    fun compute_period_adjustment(arg0: u64, arg1: u64, arg2: u64, arg3: u64) : u256 {
        ifixed_v3::ifixed::div(ifixed_v3::ifixed::mul(ifixed_v3::ifixed::from_u64(arg0 / arg2 - arg1 / arg2), ifixed_v3::ifixed::from_u64(arg2)), ifixed_v3::ifixed::from_u64(arg3))
    }
    
    public(friend) fun create_market_objects(arg0: &sui::clock::Clock, arg1: u256, arg2: u256, arg3: sui::object::ID, arg4: sui::object::ID, arg5: u64, arg6: u64, arg7: u64, arg8: u64, arg9: u64, arg10: u64, arg11: u256, arg12: u256, arg13: u256, arg14: u256, arg15: u256, arg16: u64, arg17: u64) : (MarketParams, MarketState) {
        check_market_parameters(arg1, arg2, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17);
        (create_market_params(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17), create_market_state(sui::clock::timestamp_ms(arg0)))
    }
    
    fun create_market_params(arg0: u256, arg1: u256, arg2: sui::object::ID, arg3: sui::object::ID, arg4: u64, arg5: u64, arg6: u64, arg7: u64, arg8: u64, arg9: u64, arg10: u256, arg11: u256, arg12: u256, arg13: u256, arg14: u256, arg15: u64, arg16: u64) : MarketParams {
        MarketParams{
            margin_ratio_initial      : arg0, 
            margin_ratio_maintenance  : arg1, 
            base_pfs_id               : arg2, 
            collateral_pfs_id         : arg3, 
            funding_frequency_ms      : arg4, 
            funding_period_ms         : arg5, 
            premium_twap_frequency_ms : arg6, 
            premium_twap_period_ms    : arg7, 
            spread_twap_frequency_ms  : arg8, 
            spread_twap_period_ms     : arg9, 
            maker_fee                 : arg10, 
            taker_fee                 : arg11, 
            liquidation_fee           : arg12, 
            force_cancel_fee          : arg13, 
            insurance_fund_fee        : arg14, 
            min_order_usd_value       : perpetual_v3::constants::one_fixed(), 
            lot_size                  : arg15, 
            tick_size                 : arg16, 
            liquidation_tolerance     : 1, 
            max_pending_orders        : perpetual_v3::constants::up_max_pending_orders(), 
            oracle_tolerance          : 18446744073709551615,
        }
    }
    
    fun create_market_state(arg0: u64) : MarketState {
        MarketState{
            cum_funding_rate_long    : 0, 
            cum_funding_rate_short   : 0, 
            funding_last_upd_ms      : arg0, 
            premium_twap             : 0, 
            premium_twap_last_upd_ms : arg0, 
            spread_twap              : 0, 
            spread_twap_last_upd_ms  : arg0, 
            open_interest            : 0, 
            fees_accrued             : 0,
        }
    }
    
    public fun get_base_pfs_id(arg0: &MarketParams) : sui::object::ID {
        arg0.base_pfs_id
    }
    
    public fun get_collateral_pfs_id(arg0: &MarketParams) : sui::object::ID {
        arg0.collateral_pfs_id
    }
    
    public fun get_cum_funding_rates(arg0: &MarketState) : (u256, u256) {
        (arg0.cum_funding_rate_long, arg0.cum_funding_rate_short)
    }
    
    public fun get_fees_accrued(arg0: &MarketState) : u256 {
        arg0.fees_accrued
    }
    
    public fun get_funding_last_upd_ms(arg0: &MarketState) : u64 {
        arg0.funding_last_upd_ms
    }
    
    public fun get_funding_params(arg0: &MarketParams) : (u64, u64) {
        (arg0.funding_frequency_ms, arg0.funding_period_ms)
    }
    
    public fun get_liquidation_fee_rates(arg0: &MarketParams) : (u256, u256, u256) {
        (arg0.force_cancel_fee, arg0.liquidation_fee, arg0.insurance_fund_fee)
    }
    
    public fun get_liquidation_tolerance(arg0: &MarketParams) : u64 {
        arg0.liquidation_tolerance
    }
    
    public fun get_lot_tick_sizes(arg0: &MarketParams) : (u64, u64) {
        (arg0.lot_size, arg0.tick_size)
    }
    
    public fun get_maker_taker_fees(arg0: &MarketParams) : (u256, u256) {
        (arg0.maker_fee, arg0.taker_fee)
    }
    
    public fun get_margin_ratio_initial(arg0: &MarketParams) : u256 {
        arg0.margin_ratio_initial
    }
    
    public fun get_margin_ratio_maintenance(arg0: &MarketParams) : u256 {
        arg0.margin_ratio_maintenance
    }
    
    public fun get_max_pending_orders(arg0: &MarketParams) : u64 {
        arg0.max_pending_orders
    }
    
    public fun get_min_order_usd_value(arg0: &MarketParams) : u256 {
        arg0.min_order_usd_value
    }
    
    public fun get_open_interest(arg0: &MarketState) : u256 {
        arg0.open_interest
    }
    
    public fun get_oracle_tolerance(arg0: &MarketParams) : u64 {
        arg0.oracle_tolerance
    }
    
    public fun get_premium_twap(arg0: &MarketState) : u256 {
        arg0.premium_twap
    }
    
    public fun get_premium_twap_params(arg0: &MarketParams) : (u64, u64) {
        (arg0.premium_twap_frequency_ms, arg0.premium_twap_period_ms)
    }
    
    public fun get_spread_twap(arg0: &MarketState) : u256 {
        arg0.spread_twap
    }
    
    public fun get_spread_twap_params(arg0: &MarketParams) : (u64, u64) {
        (arg0.spread_twap_frequency_ms, arg0.spread_twap_period_ms)
    }
    
    fun is_time_to_update(arg0: u64, arg1: u64, arg2: u64) : bool {
        arg0 >= next_funding_update_time(arg1, arg2)
    }
    
    fun next_funding_update_time(arg0: u64, arg1: u64) : u64 {
        arg0 - arg0 % arg1 + arg1
    }
    
    public(friend) fun reset_fees_accrued(arg0: &mut MarketState) : u256 {
        arg0.fees_accrued = 0;
        arg0.fees_accrued
    }
    
    public(friend) fun set_liquidation_tolerance(arg0: &mut MarketParams, arg1: &sui::object::ID, arg2: u64) {
        check_liquidation_tolerance(arg2);
        arg0.liquidation_tolerance = arg2;
        perpetual_v3::events::emit_updated_liquidation_tolerance(*arg1, arg2);
    }
    
    public(friend) fun set_max_pending_orders(arg0: &mut MarketParams, arg1: &sui::object::ID, arg2: u64) {
        assert!(arg2 > 0 && arg2 < perpetual_v3::constants::up_max_pending_orders(), perpetual_v3::errors::invalid_market_parameters());
        arg0.max_pending_orders = arg2;
        perpetual_v3::events::emit_updated_max_pending_orders(*arg1, arg2);
    }
    
    public(friend) fun set_min_order_usd_value(arg0: &mut MarketParams, arg1: &sui::object::ID, arg2: u256) {
        assert!(ifixed_v3::ifixed::less_than_eq(arg2, perpetual_v3::constants::up_min_order_usd_value()) && ifixed_v3::ifixed::greater_than_eq(arg2, perpetual_v3::constants::low_min_order_usd_value()), perpetual_v3::errors::invalid_market_parameters());
        arg0.min_order_usd_value = arg2;
        perpetual_v3::events::emit_updated_min_order_usd_value(*arg1, arg2);
    }
    
    public(friend) fun set_oracle_tolerance(arg0: &mut MarketParams, arg1: &sui::object::ID, arg2: u64) {
        check_oracle_tolerance(arg2);
        arg0.oracle_tolerance = arg2;
        perpetual_v3::events::emit_updated_oracle_tolerance(*arg1, arg2);
    }
    
    public(friend) fun try_update_funding(arg0: &MarketParams, arg1: &mut MarketState, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &sui::clock::Clock, arg4: &sui::object::ID, arg5: std::option::Option<u256>) {
        assert!(sui::object::id<oracle_v3::oracle::PriceFeedStorage>(arg2) == arg0.base_pfs_id, perpetual_v3::errors::invalid_price_feed_storage());
        let v0 = perpetual_v3::oracle::get_price(arg2, arg3, arg0.oracle_tolerance);
        let v1 = if (std::option::is_none<u256>(&arg5)) {
            v0
        } else {
            clip_max_book_index_spread(std::option::destroy_some<u256>(arg5), v0)
        };
        let v2 = sui::clock::timestamp_ms(arg3);
        assert!(is_time_to_update(v2, arg1.funding_last_upd_ms, arg0.funding_frequency_ms), perpetual_v3::errors::updating_funding_too_early());
        if (v2 >= arg1.premium_twap_last_upd_ms + arg0.premium_twap_frequency_ms) {
            update_premium_twap(arg1, arg0, v0, v1, v2, arg4);
        };
        update_fundings(arg1, arg0, v2, arg4);
    }
    
    public(friend) fun try_update_fundings_and_twaps(arg0: &MarketParams, arg1: &mut MarketState, arg2: u64, arg3: u256, arg4: u256, arg5: &sui::object::ID) {
        let v0 = clip_max_book_index_spread(arg4, arg3);
        if (arg2 >= arg1.premium_twap_last_upd_ms + arg0.premium_twap_frequency_ms) {
            update_premium_twap(arg1, arg0, arg3, v0, arg2, arg5);
        };
        if (arg2 >= arg1.spread_twap_last_upd_ms + arg0.spread_twap_frequency_ms) {
            update_spread_twap(arg1, arg0, arg3, v0, arg2, arg5);
        };
        if (is_time_to_update(arg2, arg1.funding_last_upd_ms, arg0.funding_frequency_ms)) {
            update_fundings(arg1, arg0, arg2, arg5);
        };
    }
    
    public(friend) fun try_update_twaps(arg0: &MarketParams, arg1: &mut MarketState, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &sui::clock::Clock, arg4: &sui::object::ID, arg5: std::option::Option<u256>) {
        assert!(sui::object::id<oracle_v3::oracle::PriceFeedStorage>(arg2) == arg0.base_pfs_id, perpetual_v3::errors::invalid_price_feed_storage());
        let v0 = perpetual_v3::oracle::get_price(arg2, arg3, arg0.oracle_tolerance);
        let v1 = if (std::option::is_none<u256>(&arg5)) {
            v0
        } else {
            clip_max_book_index_spread(std::option::destroy_some<u256>(arg5), v0)
        };
        let v2 = sui::clock::timestamp_ms(arg3);
        if (v2 >= arg1.premium_twap_last_upd_ms + arg0.premium_twap_frequency_ms) {
            update_premium_twap(arg1, arg0, v0, v1, v2, arg4);
        };
        if (v2 >= arg1.spread_twap_last_upd_ms + arg0.spread_twap_frequency_ms) {
            update_spread_twap(arg1, arg0, v0, v1, v2, arg4);
        };
    }
    
    public(friend) fun update_cum_fundings_side(arg0: &mut MarketState, arg1: &sui::object::ID, arg2: bool, arg3: u256) {
        if (arg2) {
            arg0.cum_funding_rate_long = ifixed_v3::ifixed::add(arg0.cum_funding_rate_long, arg3);
        } else {
            arg0.cum_funding_rate_short = ifixed_v3::ifixed::sub(arg0.cum_funding_rate_short, arg3);
        };
        perpetual_v3::events::emit_updated_cum_fundings(*arg1, arg0.cum_funding_rate_long, arg0.cum_funding_rate_short);
    }
    
    public(friend) fun update_fees(arg0: &mut MarketParams, arg1: &sui::object::ID, arg2: u256, arg3: u256, arg4: u256, arg5: u256, arg6: u256) {
        check_market_fees(arg2, arg3);
        check_liquidation_fees(arg4, arg5, arg6);
        arg0.maker_fee = arg2;
        arg0.taker_fee = arg3;
        arg0.liquidation_fee = arg4;
        arg0.force_cancel_fee = arg5;
        arg0.insurance_fund_fee = arg6;
        perpetual_v3::events::emit_updated_fees(*arg1, arg2, arg3, arg4, arg5, arg6);
    }
    
    public(friend) fun update_funding_parameters(arg0: &mut MarketParams, arg1: &sui::object::ID, arg2: u64, arg3: u64, arg4: u64, arg5: u64) {
        check_funding_parameters(arg2, arg3, arg4, arg5);
        arg0.funding_frequency_ms = arg2;
        arg0.funding_period_ms = arg3;
        arg0.premium_twap_frequency_ms = arg4;
        arg0.premium_twap_period_ms = arg5;
        perpetual_v3::events::emit_updated_funding_parameters(*arg1, arg2, arg3, arg4, arg5);
    }
    
    fun update_fundings(arg0: &mut MarketState, arg1: &MarketParams, arg2: u64, arg3: &sui::object::ID) {
        let v0 = ifixed_v3::ifixed::mul(arg0.premium_twap, compute_period_adjustment(arg2, arg0.funding_last_upd_ms, arg1.funding_frequency_ms, arg1.funding_period_ms));
        arg0.cum_funding_rate_long = ifixed_v3::ifixed::add(arg0.cum_funding_rate_long, v0);
        arg0.cum_funding_rate_short = ifixed_v3::ifixed::add(arg0.cum_funding_rate_short, v0);
        arg0.funding_last_upd_ms = arg2;
        perpetual_v3::events::emit_updated_funding(*arg3, arg0.cum_funding_rate_long, arg0.cum_funding_rate_short, arg0.funding_last_upd_ms);
    }
    
    public(friend) fun update_margin_ratios(arg0: &mut MarketParams, arg1: u256, arg2: u256) {
        arg0.margin_ratio_initial = arg1;
        arg0.margin_ratio_maintenance = arg2;
    }
    
    fun update_premium_twap(arg0: &mut MarketState, arg1: &MarketParams, arg2: u256, arg3: u256, arg4: u64, arg5: &sui::object::ID) {
        arg0.premium_twap = update_twap(ifixed_v3::ifixed::sub(arg3, arg2), arg0.premium_twap, arg4, arg0.premium_twap_last_upd_ms, arg1.premium_twap_period_ms);
        arg0.premium_twap_last_upd_ms = arg4;
        perpetual_v3::events::emit_updated_premium_twap(*arg5, arg3, arg2, arg0.premium_twap, arg0.premium_twap_last_upd_ms);
    }
    
    fun update_spread_twap(arg0: &mut MarketState, arg1: &MarketParams, arg2: u256, arg3: u256, arg4: u64, arg5: &sui::object::ID) {
        arg0.spread_twap = update_twap(ifixed_v3::ifixed::sub(arg3, arg2), arg0.spread_twap, arg4, arg0.spread_twap_last_upd_ms, arg1.spread_twap_period_ms);
        arg0.spread_twap_last_upd_ms = arg4;
        perpetual_v3::events::emit_updated_spread_twap(*arg5, arg3, arg2, arg0.spread_twap, arg0.spread_twap_last_upd_ms);
    }
    
    public(friend) fun update_spread_twap_parameters(arg0: &mut MarketParams, arg1: &sui::object::ID, arg2: u64, arg3: u64) {
        check_spread_twap_parameters(arg2, arg3);
        arg0.spread_twap_frequency_ms = arg2;
        arg0.spread_twap_period_ms = arg3;
        perpetual_v3::events::emit_updated_spread_twap_parameters(*arg1, arg2, arg3);
    }
    
    fun update_twap(arg0: u256, arg1: u256, arg2: u64, arg3: u64, arg4: u64) : u256 {
        let v0 = sui::math::max(arg2 - arg3, 1);
        let v1 = if (v0 >= arg4) {
            1
        } else {
            arg4 - v0
        };
        ifixed_v3::ifixed::div(ifixed_v3::ifixed::add(ifixed_v3::ifixed::mul(arg0, ifixed_v3::ifixed::from_u64(v0)), ifixed_v3::ifixed::mul(arg1, ifixed_v3::ifixed::from_u64(v1))), ifixed_v3::ifixed::from_u64(v0 + v1))
    }
    
    // decompiled from Move bytecode v6
}

