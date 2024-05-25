module perpetual_v3::position {
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
    friend perpetual_v3::registry;
    friend perpetual_v3::subaccount;

    struct Position has store {
        collateral: u256,
        base_asset_amount: u256,
        quote_asset_notional_amount: u256,
        cum_funding_rate_long: u256,
        cum_funding_rate_short: u256,
        asks_quantity: u256,
        bids_quantity: u256,
        pending_orders: u64,
        maker_fee: u256,
        taker_fee: u256,
    }
    
    public fun abs_net_base_value_and_pnl(arg0: &Position, arg1: u256) : (u256, u256) {
        let v0 = arg0.base_asset_amount;
        (ifixed_v3::ifixed::mul(ifixed_v3::ifixed::max(ifixed_v3::ifixed::abs(ifixed_v3::ifixed::add(v0, arg0.bids_quantity)), ifixed_v3::ifixed::abs(ifixed_v3::ifixed::sub(v0, arg0.asks_quantity))), arg1), ifixed_v3::ifixed::sub(ifixed_v3::ifixed::mul(v0, arg1), arg0.quote_asset_notional_amount))
    }
    
    public(friend) fun add_long_to_position(arg0: &mut Position, arg1: u256, arg2: u256) : u256 {
        if (!ifixed_v3::ifixed::is_neg(arg0.base_asset_amount)) {
            arg0.base_asset_amount = ifixed_v3::ifixed::add(arg0.base_asset_amount, arg1);
            arg0.quote_asset_notional_amount = ifixed_v3::ifixed::add(arg0.quote_asset_notional_amount, arg2);
            0
        } else {
            let v1 = ifixed_v3::ifixed::abs(arg0.base_asset_amount);
            let v2 = if (ifixed_v3::ifixed::less_than_eq(arg1, v1)) {
                let v3 = ifixed_v3::ifixed::mul(arg0.quote_asset_notional_amount, ifixed_v3::ifixed::div(arg1, v1));
                arg0.base_asset_amount = ifixed_v3::ifixed::add(arg0.base_asset_amount, arg1);
                arg0.quote_asset_notional_amount = ifixed_v3::ifixed::sub(arg0.quote_asset_notional_amount, v3);
                ifixed_v3::ifixed::sub(ifixed_v3::ifixed::neg(v3), arg2)
            } else {
                let v4 = ifixed_v3::ifixed::mul(arg2, ifixed_v3::ifixed::div(v1, arg1));
                arg0.base_asset_amount = ifixed_v3::ifixed::add(arg0.base_asset_amount, arg1);
                arg0.quote_asset_notional_amount = ifixed_v3::ifixed::sub(arg2, v4);
                ifixed_v3::ifixed::sub(ifixed_v3::ifixed::neg(arg0.quote_asset_notional_amount), v4)
            };
            v2
        }
    }
    
    public(friend) fun add_short_to_position(arg0: &mut Position, arg1: u256, arg2: u256) : u256 {
        if (ifixed_v3::ifixed::less_than_eq(arg0.base_asset_amount, 0)) {
            arg0.base_asset_amount = ifixed_v3::ifixed::sub(arg0.base_asset_amount, arg1);
            arg0.quote_asset_notional_amount = ifixed_v3::ifixed::sub(arg0.quote_asset_notional_amount, arg2);
            0
        } else {
            let v1 = ifixed_v3::ifixed::abs(arg0.base_asset_amount);
            let v2 = if (ifixed_v3::ifixed::less_than_eq(arg1, v1)) {
                let v3 = ifixed_v3::ifixed::mul(arg0.quote_asset_notional_amount, ifixed_v3::ifixed::div(arg1, v1));
                arg0.base_asset_amount = ifixed_v3::ifixed::sub(arg0.base_asset_amount, arg1);
                arg0.quote_asset_notional_amount = ifixed_v3::ifixed::sub(arg0.quote_asset_notional_amount, v3);
                ifixed_v3::ifixed::sub(arg2, v3)
            } else {
                let v4 = ifixed_v3::ifixed::mul(arg2, ifixed_v3::ifixed::div(v1, arg1));
                arg0.base_asset_amount = ifixed_v3::ifixed::sub(arg0.base_asset_amount, arg1);
                arg0.quote_asset_notional_amount = ifixed_v3::ifixed::neg(ifixed_v3::ifixed::sub(arg2, v4));
                ifixed_v3::ifixed::sub(v4, arg0.quote_asset_notional_amount)
            };
            v2
        }
    }
    
    public(friend) fun add_to_collateral(arg0: &mut Position, arg1: u256) {
        arg0.collateral = ifixed_v3::ifixed::add(arg0.collateral, arg1);
    }
    
    public(friend) fun add_to_collateral_usd(arg0: &mut Position, arg1: u256, arg2: u256) : u256 {
        arg0.collateral = ifixed_v3::ifixed::add(arg0.collateral, ifixed_v3::ifixed::div(arg1, arg2));
        arg0.collateral
    }
    
    public(friend) fun add_to_pending_amount(arg0: &mut Position, arg1: bool, arg2: u256) {
        if (arg1) {
            arg0.asks_quantity = ifixed_v3::ifixed::add(arg0.asks_quantity, arg2);
        } else {
            arg0.bids_quantity = ifixed_v3::ifixed::add(arg0.bids_quantity, arg2);
        };
    }
    
    fun calculate_position_funding_internal(arg0: &mut Position, arg1: u256, arg2: u256) : u256 {
        let v0 = if (ifixed_v3::ifixed::is_neg(arg0.base_asset_amount)) {
            unrealized_funding(arg2, arg0.cum_funding_rate_short, arg0.base_asset_amount)
        } else {
            unrealized_funding(arg1, arg0.cum_funding_rate_long, arg0.base_asset_amount)
        };
        arg0.cum_funding_rate_long = arg1;
        arg0.cum_funding_rate_short = arg2;
        v0
    }
    
    public fun compute_free_collateral(arg0: &Position, arg1: u256, arg2: u256, arg3: u256) : u256 {
        let (v0, v1) = get_pnl_and_min_margin_in_position(arg0, arg2, arg3);
        let v2 = if (ifixed_v3::ifixed::less_than(v0, 0)) {
            ifixed_v3::ifixed::add(ifixed_v3::ifixed::mul(arg0.collateral, arg1), v0)
        } else {
            ifixed_v3::ifixed::mul(arg0.collateral, arg1)
        };
        if (ifixed_v3::ifixed::greater_than_eq(v2, v1)) {
            ifixed_v3::ifixed::div(ifixed_v3::ifixed::sub(v2, v1), arg1)
        } else {
            0
        }
    }
    
    public fun compute_margin(arg0: &Position, arg1: u256, arg2: u256, arg3: u256) : (u256, u256) {
        let (v0, v1) = get_pnl_and_min_margin_in_position(arg0, arg2, arg3);
        (ifixed_v3::ifixed::add(ifixed_v3::ifixed::mul(arg0.collateral, arg1), v0), v1)
    }
    
    public(friend) fun create_position(arg0: u256, arg1: u256) : Position {
        Position{
            collateral                  : 0, 
            base_asset_amount           : 0, 
            quote_asset_notional_amount : 0, 
            cum_funding_rate_long       : arg0, 
            cum_funding_rate_short      : arg1, 
            asks_quantity               : 0, 
            bids_quantity               : 0, 
            pending_orders              : 0, 
            maker_fee                   : perpetual_v3::constants::null_fee(), 
            taker_fee                   : perpetual_v3::constants::null_fee(),
        }
    }
    
    public fun ensure_initial_margin_requirements(arg0: u256, arg1: u256, arg2: u256, arg3: u256) {
        if (ifixed_v3::ifixed::greater_than_eq(arg2, arg3)) {
            return
        };
        assert!(arg1 != 0, perpetual_v3::errors::initial_margin_requirements_violated());
        assert!(!ifixed_v3::ifixed::is_neg(arg2) && !ifixed_v3::ifixed::is_neg(arg0), perpetual_v3::errors::position_bad_debt());
        let v0 = if (arg3 != 0) {
            ifixed_v3::ifixed::div(arg2, arg3)
        } else {
            0
        };
        assert!(ifixed_v3::ifixed::greater_than_eq(v0, ifixed_v3::ifixed::div(arg0, arg1)), perpetual_v3::errors::initial_margin_requirements_violated());
    }
    
    public fun ensure_margin_requirements(arg0: &Position, arg1: u256, arg2: u256, arg3: u256, arg4: u256, arg5: u256) {
        let (v0, v1) = get_pnl_and_min_margin_in_position(arg0, arg2, arg3);
        ensure_initial_margin_requirements(arg4, arg5, ifixed_v3::ifixed::add(ifixed_v3::ifixed::mul(arg0.collateral, arg1), v0), v1);
    }
    
    public fun get_amounts(arg0: &Position) : (u256, u256) {
        (arg0.base_asset_amount, arg0.quote_asset_notional_amount)
    }
    
    public fun get_collateral(arg0: &Position) : u256 {
        arg0.collateral
    }
    
    public fun get_maker_fee(arg0: &Position) : u256 {
        arg0.maker_fee
    }
    
    public fun get_pending_amounts(arg0: &Position) : (u256, u256) {
        (arg0.asks_quantity, arg0.bids_quantity)
    }
    
    public fun get_pending_orders_counter(arg0: &Position) : u64 {
        arg0.pending_orders
    }
    
    public fun get_pnl_and_min_margin_in_position(arg0: &Position, arg1: u256, arg2: u256) : (u256, u256) {
        let (v0, v1) = abs_net_base_value_and_pnl(arg0, arg1);
        (v1, ifixed_v3::ifixed::mul(v0, arg2))
    }
    
    public fun get_pos_funding_rates(arg0: &Position) : (u256, u256) {
        (arg0.cum_funding_rate_long, arg0.cum_funding_rate_short)
    }
    
    public fun get_taker_fee(arg0: &Position) : u256 {
        arg0.taker_fee
    }
    
    public(friend) fun reset_collateral(arg0: &mut Position) : u256 {
        arg0.collateral = 0;
        ifixed_v3::ifixed::abs(arg0.collateral)
    }
    
    public(friend) fun settle_position_funding(arg0: &mut Position, arg1: u256, arg2: u256, arg3: u256, arg4: &sui::object::ID, arg5: u64) {
        let v0 = calculate_position_funding_internal(arg0, arg2, arg3);
        if (v0 != 0) {
            perpetual_v3::events::emit_settled_funding(*arg4, arg5, v0, add_to_collateral_usd(arg0, v0, arg1), arg2, arg3);
        };
    }
    
    public(friend) fun sub_from_collateral(arg0: &mut Position, arg1: u256) {
        arg0.collateral = ifixed_v3::ifixed::sub(arg0.collateral, arg1);
    }
    
    public(friend) fun sub_from_collateral_usd(arg0: &mut Position, arg1: u256, arg2: u256) {
        arg0.collateral = ifixed_v3::ifixed::sub(arg0.collateral, ifixed_v3::ifixed::div(arg1, arg2));
    }
    
    public(friend) fun sub_from_pending_amount(arg0: &mut Position, arg1: bool, arg2: u256) {
        if (arg1) {
            arg0.asks_quantity = ifixed_v3::ifixed::sub(arg0.asks_quantity, arg2);
        } else {
            arg0.bids_quantity = ifixed_v3::ifixed::sub(arg0.bids_quantity, arg2);
        };
    }
    
    fun unrealized_funding(arg0: u256, arg1: u256, arg2: u256) : u256 {
        if (arg0 == arg1) {
            return 0
        };
        ifixed_v3::ifixed::mul(ifixed_v3::ifixed::sub(arg0, arg1), ifixed_v3::ifixed::neg(arg2))
    }
    
    public(friend) fun update_pending_orders(arg0: &mut Position, arg1: bool, arg2: u64) {
        if (arg1) {
            arg0.pending_orders = arg0.pending_orders + arg2;
        } else {
            arg0.pending_orders = arg0.pending_orders - arg2;
        };
    }
    
    public(friend) fun update_position_fees(arg0: &mut Position, arg1: u256, arg2: u256) {
        arg0.maker_fee = arg1;
        arg0.taker_fee = arg2;
    }
    
    // decompiled from Move bytecode v6
}

