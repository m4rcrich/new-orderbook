module perpetual_v3::clearing_house {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};
    friend perpetual_v3::account;
    friend perpetual_v3::admin;
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
    struct ClearingHouse<phantom T0> has key {
        id: sui::object::UID,
        version: u64,
        market_params: perpetual_v3::market::MarketParams,
        market_state: perpetual_v3::market::MarketState,
    }
    
    struct Vault<phantom T0> has store {
        collateral_balance: sui::balance::Balance<T0>,
        insurance_fund_balance: sui::balance::Balance<T0>,
        scaling_factor: u256,
    }
    
    struct MarginRatioProposal has store {
        maturity: u64,
        margin_ratio_initial: u256,
        margin_ratio_maintenance: u256,
    }
    
    struct PositionFeesProposal has store {
        maker_fee: u256,
        taker_fee: u256,
    }
    
    struct SessionHotPotato<phantom T0> {
        clearing_house: ClearingHouse<T0>,
        account_id: u64,
        timestamp_ms: u64,
        collateral_price: u256,
        index_price: u256,
        book_price: u256,
        margin_before: u256,
        min_margin_before: u256,
        fills: vector<perpetual_v3::orderbook::FillReceipt>,
        post: perpetual_v3::orderbook::PostReceipt,
        liquidation_receipt: std::option::Option<LiquidationReceipt>,
    }
    
    struct LiquidationReceipt has drop, store {
        liqee_account_id: u64,
        size_to_liquidate: u64,
        base_ask_cancel: u64,
        base_bid_cancel: u64,
        pending_orders: u64,
    }
    
    fun best_price(arg0: &perpetual_v3::orderbook::Orderbook, arg1: bool, arg2: u64, arg3: u64) : std::option::Option<u256> {
        let v0 = perpetual_v3::orderbook::best_price(arg0, arg1);
        if (std::option::is_none<u64>(&v0)) {
            return std::option::none<u256>()
        };
        std::option::some<u256>(ticks_per_lot_to_quote_per_base(std::option::destroy_some<u64>(v0), arg2, arg3))
    }
    
    fun book_price(arg0: &perpetual_v3::orderbook::Orderbook, arg1: u64, arg2: u64) : std::option::Option<u256> {
        let v0 = perpetual_v3::orderbook::book_price(arg0);
        if (std::option::is_none<u64>(&v0)) {
            return std::option::none<u256>()
        };
        std::option::some<u256>(ticks_per_lot_to_quote_per_base(std::option::destroy_some<u64>(v0), arg1, arg2))
    }
    
    public(friend) fun place_limit_order<T0>(arg0: &mut SessionHotPotato<T0>, arg1: bool, arg2: u64, arg3: u64, arg4: u64) {
        assert!(arg2 != 0 && arg3 != 0, perpetual_v3::errors::invalid_size_or_price());
        let v0 = sui::object::id<ClearingHouse<T0>>(&arg0.clearing_house);
        let (v1, v2) = perpetual_v3::market::get_lot_tick_sizes(&arg0.clearing_house.market_params);
        let v3 = get_orderbook_mut<T0>(&mut arg0.clearing_house);
        let v4 = arg0.index_price;
        let v5 = perpetual_v3::orderbook::place_limit_order(v3, arg0.account_id, arg1, arg2, arg3, arg4, &mut arg0.fills, &mut arg0.post, &v0);
        if (v5 != 0) {
            check_order_value(v5, v1, v4, perpetual_v3::market::get_min_order_usd_value(&arg0.clearing_house.market_params));
        };
        arg0.book_price = book_price_or_index(v3, v4, v1, v2);
    }
    
    public(friend) fun place_market_order<T0>(arg0: &mut SessionHotPotato<T0>, arg1: bool, arg2: u64) {
        assert!(arg2 != 0, perpetual_v3::errors::invalid_size_or_price());
        let (v0, v1) = perpetual_v3::market::get_lot_tick_sizes(&arg0.clearing_house.market_params);
        let v2 = get_orderbook_mut<T0>(&mut arg0.clearing_house);
        perpetual_v3::orderbook::place_market_order(v2, arg0.account_id, arg1, arg2, &mut arg0.fills);
        arg0.book_price = book_price_or_index(v2, arg0.index_price, v0, v1);
    }
    
    public(friend) fun accept_position_fees_proposal<T0>(arg0: &mut ClearingHouse<T0>, arg1: &perpetual_v3::account::Account<T0>) {
        let v0 = perpetual_v3::account::get_account_id<T0>(arg1);
        let v1 = perpetual_v3::keys::position_fees_proposal(v0);
        assert!(sui::dynamic_field::exists_<perpetual_v3::keys::PositionFeesProposal>(&arg0.id, v1), perpetual_v3::errors::proposal_does_not_exist());
        let PositionFeesProposal {
            maker_fee : v2,
            taker_fee : v3,
        } = sui::dynamic_field::remove<perpetual_v3::keys::PositionFeesProposal, PositionFeesProposal>(&mut arg0.id, v1);
        perpetual_v3::position::update_position_fees(get_position_mut<T0>(arg0, v0), v2, v3);
        perpetual_v3::events::emit_accepted_position_fees_proposal(sui::object::id<ClearingHouse<T0>>(arg0), v0, v2, v3);
    }
    
    fun add_position<T0>(arg0: &mut ClearingHouse<T0>, arg1: u64, arg2: perpetual_v3::position::Position) {
        assert!(!sui::dynamic_field::exists_<perpetual_v3::keys::Position>(&arg0.id, perpetual_v3::keys::position(arg1)), perpetual_v3::errors::position_already_exists());
        sui::dynamic_field::add<perpetual_v3::keys::Position, perpetual_v3::position::Position>(&mut arg0.id, perpetual_v3::keys::position(arg1), arg2);
    }
    
    public(friend) fun allocate_collateral<T0>(arg0: &mut ClearingHouse<T0>, arg1: &mut perpetual_v3::account::Account<T0>, arg2: u64) {
        assert!(arg2 != 0, perpetual_v3::errors::deposit_or_withdraw_amount_zero());
        let v0 = perpetual_v3::account::get_account_id<T0>(arg1);
        let v1 = sui::balance::split<T0>(perpetual_v3::account::get_collateral_mut<T0>(arg1), arg2);
        let v2 = get_market_vault_mut<T0>(arg0);
        sui::balance::join<T0>(&mut v2.collateral_balance, v1);
        let v3 = get_position_mut<T0>(arg0, v0);
        perpetual_v3::position::add_to_collateral(v3, ifixed_v3::ifixed::from_balance(sui::balance::value<T0>(&v1), v2.scaling_factor));
        perpetual_v3::events::emit_allocated_collateral(sui::object::id<ClearingHouse<T0>>(arg0), v0, arg2, perpetual_v3::account::get_collateral_value<T0>(arg1), perpetual_v3::position::get_collateral(v3), sui::balance::value<T0>(&v2.collateral_balance));
    }
    
    public(friend) fun allocate_collateral_subaccount<T0>(arg0: &mut ClearingHouse<T0>, arg1: &mut perpetual_v3::subaccount::SubAccount<T0>, arg2: u64) {
        assert!(arg2 != 0, perpetual_v3::errors::deposit_or_withdraw_amount_zero());
        let v0 = perpetual_v3::subaccount::get_account_id<T0>(arg1);
        let v1 = sui::balance::split<T0>(perpetual_v3::subaccount::get_collateral_mut<T0>(arg1), arg2);
        let v2 = get_market_vault_mut<T0>(arg0);
        sui::balance::join<T0>(&mut v2.collateral_balance, v1);
        let v3 = get_position_mut<T0>(arg0, v0);
        perpetual_v3::position::add_to_collateral(v3, ifixed_v3::ifixed::from_balance(sui::balance::value<T0>(&v1), v2.scaling_factor));
        perpetual_v3::events::emit_allocated_collateral_subaccount(sui::object::id<ClearingHouse<T0>>(arg0), sui::object::id<perpetual_v3::subaccount::SubAccount<T0>>(arg1), v0, arg2, perpetual_v3::subaccount::get_collateral_value<T0>(arg1), perpetual_v3::position::get_collateral(v3), sui::balance::value<T0>(&v2.collateral_balance));
    }
    
    fun book_price_or_index(arg0: &perpetual_v3::orderbook::Orderbook, arg1: u256, arg2: u64, arg3: u64) : u256 {
        let v0 = book_price(arg0, arg2, arg3);
        if (std::option::is_some<u256>(&v0)) {
            std::option::destroy_some<u256>(v0)
        } else {
            arg1
        }
    }
    
    public(friend) fun cancel_orders<T0>(arg0: &mut ClearingHouse<T0>, arg1: u64, arg2: &vector<u128>) {
        let v0 = std::vector::length<u128>(arg2);
        assert!(v0 != 0, perpetual_v3::errors::invalid_cancel_order_ids());
        let v1 = sui::object::id<ClearingHouse<T0>>(arg0);
        let v2 = 0;
        let v3 = 0;
        let v4 = 0;
        while (v4 < v0) {
            let v5 = *std::vector::borrow<u128>(arg2, v4);
            let v6 = perpetual_v3::orderbook::cancel_limit_order(get_orderbook_mut<T0>(arg0), arg1, v5);
            if (perpetual_v3::order_id::is_ask(v5)) {
                v2 = v2 + v6;
            } else {
                v3 = v3 + v6;
            };
            perpetual_v3::events::emit_canceled_order(v1, arg1, v5, v6);
            v4 = v4 + 1;
        };
        let (v7, _) = perpetual_v3::market::get_lot_tick_sizes(&arg0.market_params);
        let v9 = get_position_mut<T0>(arg0, arg1);
        perpetual_v3::position::sub_from_pending_amount(v9, perpetual_v3::constants::ask(), ifixed_v3::ifixed::from_balance(v2 * v7, perpetual_v3::constants::b9_scaling()));
        perpetual_v3::position::sub_from_pending_amount(v9, perpetual_v3::constants::bid(), ifixed_v3::ifixed::from_balance(v3 * v7, perpetual_v3::constants::b9_scaling()));
        perpetual_v3::position::update_pending_orders(v9, false, v0);
        let (v10, v11) = perpetual_v3::position::get_pending_amounts(v9);
        perpetual_v3::events::emit_canceled_orders(v1, arg1, v10, v11, perpetual_v3::position::get_pending_orders_counter(v9));
    }
    
    public fun check_ch_version<T0>(arg0: &ClearingHouse<T0>) {
        assert!(arg0.version == perpetual_v3::constants::version(), perpetual_v3::errors::wrong_version());
    }
    
    public fun check_ch_version_in_session<T0>(arg0: &SessionHotPotato<T0>) {
        assert!(arg0.clearing_house.version == perpetual_v3::constants::version(), perpetual_v3::errors::wrong_version());
    }
    
    fun check_oracle_price_feed_storages(arg0: &perpetual_v3::market::MarketParams, arg1: &oracle_v3::oracle::PriceFeedStorage, arg2: &oracle_v3::oracle::PriceFeedStorage) {
        assert!(sui::object::id<oracle_v3::oracle::PriceFeedStorage>(arg1) == perpetual_v3::market::get_base_pfs_id(arg0), perpetual_v3::errors::invalid_price_feed_storage());
        assert!(sui::object::id<oracle_v3::oracle::PriceFeedStorage>(arg2) == perpetual_v3::market::get_collateral_pfs_id(arg0), perpetual_v3::errors::invalid_price_feed_storage());
    }
    
    fun check_order_value(arg0: u64, arg1: u64, arg2: u256, arg3: u256) {
        assert!(ifixed_v3::ifixed::mul(ifixed_v3::ifixed::from_balance(arg0 * arg1, perpetual_v3::constants::b9_scaling()), arg2) >= arg3, perpetual_v3::errors::order_usd_value_too_low());
    }
    
    public(friend) fun commit_margin_ratios_proposal<T0>(arg0: &mut ClearingHouse<T0>, arg1: &sui::clock::Clock) {
        let v0 = perpetual_v3::keys::margin_ratio_proposal();
        assert!(sui::dynamic_field::exists_<perpetual_v3::keys::MarginRatioProposal>(&arg0.id, v0), perpetual_v3::errors::proposal_does_not_exist());
        let MarginRatioProposal {
            maturity                 : v1,
            margin_ratio_initial     : v2,
            margin_ratio_maintenance : v3,
        } = sui::dynamic_field::remove<perpetual_v3::keys::MarginRatioProposal, MarginRatioProposal>(&mut arg0.id, v0);
        assert!(v1 <= sui::clock::timestamp_ms(arg1), perpetual_v3::errors::premature_proposal());
        perpetual_v3::market::update_margin_ratios(&mut arg0.market_params, v2, v3);
        perpetual_v3::events::emit_updated_margin_ratios(sui::object::id<ClearingHouse<T0>>(arg0), v2, v3);
    }
    
    fun compute_and_set_tolerance_diff(arg0: u64, arg1: u256, arg2: u256, arg3: u256, arg4: u256, arg5: u256, arg6: u64, arg7: bool, arg8: u256) : (u256, u256) {
        let v0 = ifixed_v3::ifixed::min(arg8, ifixed_v3::ifixed::from_balance(arg0 * arg6, perpetual_v3::constants::b9_scaling()));
        let v1 = if (arg7) {
            v0
        } else {
            ifixed_v3::ifixed::neg(v0)
        };
        (ifixed_v3::ifixed::add(ifixed_v3::ifixed::mul(v1, ifixed_v3::ifixed::sub(arg3, arg2)), ifixed_v3::ifixed::mul(ifixed_v3::ifixed::mul(v0, arg2), ifixed_v3::ifixed::add(arg4, arg5))), ifixed_v3::ifixed::mul(ifixed_v3::ifixed::mul(v0, arg3), arg1))
    }
    
    public(friend) fun create_clearing_house<T0>(arg0: perpetual_v3::orderbook::Orderbook, arg1: &sui::coin::CoinMetadata<T0>, arg2: &sui::clock::Clock, arg3: &oracle_v3::oracle::PriceFeedStorage, arg4: &oracle_v3::oracle::PriceFeedStorage, arg5: u256, arg6: u256, arg7: u64, arg8: u64, arg9: u64, arg10: u64, arg11: u64, arg12: u64, arg13: u256, arg14: u256, arg15: u256, arg16: u256, arg17: u256, arg18: u64, arg19: u64, arg20: &mut sui::tx_context::TxContext) : ClearingHouse<T0> {
        assert!(oracle_v3::oracle::any_source(arg3), perpetual_v3::errors::no_price_feed_for_market());
        assert!(oracle_v3::oracle::any_source(arg4), perpetual_v3::errors::no_price_feed_for_market());
        let v0 = sui::object::id<oracle_v3::oracle::PriceFeedStorage>(arg3);
        let v1 = sui::object::id<oracle_v3::oracle::PriceFeedStorage>(arg4);
        let v2 = (sui::coin::get_decimals<T0>(arg1) as u64);
        let v3 = Vault<T0>{
            collateral_balance     : sui::balance::zero<T0>(), 
            insurance_fund_balance : sui::balance::zero<T0>(), 
            scaling_factor         : (ifixed_v3::ifixed::decimal_scalar_from_decimals(v2) as u256),
        };
        let (v4, v5) = perpetual_v3::market::create_market_objects(arg2, arg5, arg6, v0, v1, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19);
        let v6 = ClearingHouse<T0>{
            id            : sui::object::new(arg20), 
            version       : perpetual_v3::constants::version(), 
            market_params : v4, 
            market_state  : v5,
        };
        sui::dynamic_field::add<perpetual_v3::keys::MarketVault, Vault<T0>>(&mut v6.id, perpetual_v3::keys::market_vault(), v3);
        sui::dynamic_object_field::add<perpetual_v3::keys::Orderbook, perpetual_v3::orderbook::Orderbook>(&mut v6.id, perpetual_v3::keys::market_orderbook(), arg0);
        perpetual_v3::events::emit_created_clearing_house(sui::object::id<ClearingHouse<T0>>(&v6), get_collateral_symbol<T0>(), v2, arg5, arg6, v0, v1, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19);
        v6
    }
    
    public(friend) fun create_margin_ratios_proposal<T0>(arg0: &mut ClearingHouse<T0>, arg1: &sui::clock::Clock, arg2: u64, arg3: u256, arg4: u256) {
        assert!(!sui::dynamic_field::exists_<perpetual_v3::keys::MarginRatioProposal>(&arg0.id, perpetual_v3::keys::margin_ratio_proposal()), perpetual_v3::errors::proposal_already_exists());
        assert!(perpetual_v3::constants::min_proposal_delay_ms() <= arg2 && arg2 <= perpetual_v3::constants::max_proposal_delay_ms(), perpetual_v3::errors::invalid_proposal_delay());
        perpetual_v3::market::check_margin_ratios(arg3, arg4);
        let v0 = MarginRatioProposal{
            maturity                 : sui::clock::timestamp_ms(arg1) + arg2, 
            margin_ratio_initial     : arg3, 
            margin_ratio_maintenance : arg4,
        };
        sui::dynamic_field::add<perpetual_v3::keys::MarginRatioProposal, MarginRatioProposal>(&mut arg0.id, perpetual_v3::keys::margin_ratio_proposal(), v0);
        perpetual_v3::events::emit_created_margin_ratios_proposal(sui::object::id<ClearingHouse<T0>>(arg0), arg3, arg4);
    }
    
    public(friend) fun create_market_position<T0>(arg0: &mut ClearingHouse<T0>, arg1: &perpetual_v3::account::Account<T0>) {
        let (v0, v1) = perpetual_v3::market::get_cum_funding_rates(&arg0.market_state);
        let v2 = perpetual_v3::account::get_account_id<T0>(arg1);
        add_position<T0>(arg0, v2, perpetual_v3::position::create_position(v0, v1));
        perpetual_v3::events::emit_created_position(sui::object::id<ClearingHouse<T0>>(arg0), v2, v0, v1);
    }
    
    public(friend) fun create_position_fees_proposal<T0>(arg0: &mut ClearingHouse<T0>, arg1: u64, arg2: u256, arg3: u256) {
        assert!(!sui::dynamic_field::exists_<perpetual_v3::keys::PositionFeesProposal>(&arg0.id, perpetual_v3::keys::position_fees_proposal(arg1)), perpetual_v3::errors::proposal_already_exists());
        let (v0, v1) = perpetual_v3::market::get_maker_taker_fees(&arg0.market_params);
        if (arg2 != perpetual_v3::constants::null_fee()) {
            perpetual_v3::market::check_market_fees(arg2, v1);
        };
        if (arg3 != perpetual_v3::constants::null_fee()) {
            perpetual_v3::market::check_market_fees(v0, arg3);
        };
        let v2 = PositionFeesProposal{
            maker_fee : arg2, 
            taker_fee : arg3,
        };
        sui::dynamic_field::add<perpetual_v3::keys::PositionFeesProposal, PositionFeesProposal>(&mut arg0.id, perpetual_v3::keys::position_fees_proposal(arg1), v2);
        perpetual_v3::events::emit_created_position_fees_proposal(sui::object::id<ClearingHouse<T0>>(arg0), arg1, arg2, arg3);
    }
    
    public(friend) fun deallocate_collateral<T0>(arg0: &mut ClearingHouse<T0>, arg1: &mut perpetual_v3::account::Account<T0>, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &oracle_v3::oracle::PriceFeedStorage, arg4: &sui::clock::Clock, arg5: u64) {
        assert!(arg5 != 0, perpetual_v3::errors::deposit_or_withdraw_amount_zero());
        let v0 = perpetual_v3::account::get_account_id<T0>(arg1);
        let (v1, v2, v3) = take_collateral<T0>(arg0, arg2, arg3, arg4, v0, arg5);
        sui::balance::join<T0>(perpetual_v3::account::get_collateral_mut<T0>(arg1), v1);
        perpetual_v3::events::emit_deallocated_collateral(sui::object::id<ClearingHouse<T0>>(arg0), v0, arg5, perpetual_v3::account::get_collateral_value<T0>(arg1), v2, v3);
    }
    
    public(friend) fun deallocate_collateral_subaccount<T0>(arg0: &mut ClearingHouse<T0>, arg1: &mut perpetual_v3::subaccount::SubAccount<T0>, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &oracle_v3::oracle::PriceFeedStorage, arg4: &sui::clock::Clock, arg5: u64) {
        assert!(arg5 != 0, perpetual_v3::errors::deposit_or_withdraw_amount_zero());
        let v0 = perpetual_v3::subaccount::get_account_id<T0>(arg1);
        let (v1, v2, v3) = take_collateral<T0>(arg0, arg2, arg3, arg4, v0, arg5);
        sui::balance::join<T0>(perpetual_v3::subaccount::get_collateral_mut<T0>(arg1), v1);
        perpetual_v3::events::emit_deallocated_collateral_subaccount(sui::object::id<ClearingHouse<T0>>(arg0), sui::object::id<perpetual_v3::subaccount::SubAccount<T0>>(arg1), v0, arg5, perpetual_v3::subaccount::get_collateral_value<T0>(arg1), v2, v3);
    }
    
    public(friend) fun delete_margin_ratios_proposal<T0>(arg0: &mut ClearingHouse<T0>, arg1: &sui::clock::Clock) {
        let v0 = perpetual_v3::keys::margin_ratio_proposal();
        assert!(sui::dynamic_field::exists_<perpetual_v3::keys::MarginRatioProposal>(&arg0.id, v0), perpetual_v3::errors::proposal_does_not_exist());
        let MarginRatioProposal {
            maturity                 : v1,
            margin_ratio_initial     : v2,
            margin_ratio_maintenance : v3,
        } = sui::dynamic_field::remove<perpetual_v3::keys::MarginRatioProposal, MarginRatioProposal>(&mut arg0.id, v0);
        assert!(sui::clock::timestamp_ms(arg1) < v1, perpetual_v3::errors::proposal_already_matured());
        perpetual_v3::events::emit_deleted_margin_ratios_proposal(sui::object::id<ClearingHouse<T0>>(arg0), v2, v3);
    }
    
    public(friend) fun delete_position_fees_proposal<T0>(arg0: &mut ClearingHouse<T0>, arg1: u64) {
        let v0 = perpetual_v3::keys::position_fees_proposal(arg1);
        assert!(sui::dynamic_field::exists_<perpetual_v3::keys::PositionFeesProposal>(&arg0.id, v0), perpetual_v3::errors::proposal_does_not_exist());
        let PositionFeesProposal {
            maker_fee : v1,
            taker_fee : v2,
        } = sui::dynamic_field::remove<perpetual_v3::keys::PositionFeesProposal, PositionFeesProposal>(&mut arg0.id, v0);
        perpetual_v3::events::emit_deleted_position_fees_proposal(sui::object::id<ClearingHouse<T0>>(arg0), arg1, v1, v2);
    }
    
    fun distribute_debt<T0>(arg0: &mut ClearingHouse<T0>, arg1: u256, arg2: u256, arg3: bool, arg4: &sui::object::ID) {
        let v0 = get_market_vault_mut<T0>(arg0);
        let v1 = ifixed_v3::ifixed::from_balance(sui::balance::value<T0>(&v0.insurance_fund_balance), v0.scaling_factor);
        if (ifixed_v3::ifixed::greater_than_eq(v1, arg1)) {
            transfer_from_insurance_fund_to_vault<T0>(v0, arg1);
        } else {
            transfer_from_insurance_fund_to_vault<T0>(v0, v1);
            socialize_debt(&mut arg0.market_state, arg3, ifixed_v3::ifixed::mul(ifixed_v3::ifixed::sub(arg1, v1), arg2), arg4);
        };
    }
    
    public(friend) fun donate_to_insurance_fund<T0>(arg0: &mut ClearingHouse<T0>, arg1: sui::coin::Coin<T0>, arg2: address) {
        perpetual_v3::events::emit_donated_to_insurance_fund(arg2, sui::object::id<ClearingHouse<T0>>(arg0), sui::balance::join<T0>(&mut get_market_vault_mut<T0>(arg0).insurance_fund_balance, sui::coin::into_balance<T0>(arg1)));
    }
    
    public(friend) fun end_session<T0>(arg0: SessionHotPotato<T0>) : ClearingHouse<T0> {
        let SessionHotPotato {
            clearing_house      : v0,
            account_id          : v1,
            timestamp_ms        : v2,
            collateral_price    : v3,
            index_price         : v4,
            book_price          : v5,
            margin_before       : v6,
            min_margin_before   : v7,
            fills               : v8,
            post                : v9,
            liquidation_receipt : v10,
        } = arg0;
        let v11 = v10;
        let v12 = v9;
        let v13 = v8;
        let v14 = v0;
        let v15 = sui::object::id<ClearingHouse<T0>>(&v14);
        let v16 = 0;
        let v17 = 0;
        let v18 = 0;
        let v19 = 0;
        let v20 = 0;
        let v21 = 0;
        let (v22, v23) = if (std::option::is_some<LiquidationReceipt>(&v11)) {
            let (v24, v25) = execute_liquidation<T0>(&mut v14, std::option::borrow<LiquidationReceipt>(&v11), v3, v4, v5, v2, v1, &mut v16, &mut v17, &mut v18, &mut v19, &mut v21, &v15);
            (v24, v25)
        } else {
            let (_, _, v28) = perpetual_v3::orderbook::get_post_receipt_info(&v12);
            assert!(v28 != 0 || !std::vector::is_empty<perpetual_v3::orderbook::FillReceipt>(&v13), perpetual_v3::errors::empty_session());
            (0, 0)
        };
        let (v29, v30) = get_market_objects<T0>(&v14);
        let (v31, v32) = perpetual_v3::market::get_lot_tick_sizes(v29);
        let (v33, v34) = perpetual_v3::market::get_maker_taker_fees(v29);
        let (v35, v36) = perpetual_v3::market::get_cum_funding_rates(v30);
        let v37 = 0;
        while (v37 < std::vector::length<perpetual_v3::orderbook::FillReceipt>(&v13)) {
            let v38 = std::vector::borrow<perpetual_v3::orderbook::FillReceipt>(&v13, v37);
            v37 = v37 + 1;
            let (v39, v40, v41, v42, v43) = process_fill_maker<T0>(&mut v14, v3, v31, v32, v33, v35, v36, v38, &v15);
            if (v39 == perpetual_v3::constants::ask()) {
                v18 = ifixed_v3::ifixed::add(v18, v40);
                v19 = ifixed_v3::ifixed::add(v19, v41);
            } else {
                v16 = ifixed_v3::ifixed::add(v16, v40);
                v17 = ifixed_v3::ifixed::add(v17, v41);
            };
            v20 = ifixed_v3::ifixed::add(v20, v42);
            v21 = ifixed_v3::ifixed::add(v21, v43);
        };
        let v44 = get_position_mut<T0>(&mut v14, v1);
        if (v22 != 0) {
            perpetual_v3::position::add_to_collateral_usd(v44, v22, v3);
        };
        let (v45, v46) = if (v16 != 0 || v18 != 0) {
            let (v47, v48) = process_fill_taker(v44, v3, v1, v16, v17, v18, v19, v34, v23, &v15);
            (v47, v48)
        } else {
            (0, 0)
        };
        process_post(v44, v1, v31, perpetual_v3::market::get_max_pending_orders(v29), &v12, &v15);
        perpetual_v3::position::ensure_margin_requirements(v44, v3, v4, perpetual_v3::market::get_margin_ratio_initial(v29), v6, v7);
        perpetual_v3::market::try_update_fundings_and_twaps(&v14.market_params, &mut v14.market_state, v2, v4, v5, &v15);
        let v49 = ifixed_v3::ifixed::add(v20, v45);
        v21 = ifixed_v3::ifixed::add(v21, v46);
        if (v49 != 0 || v21 != 0) {
            let v50 = get_market_state_mut<T0>(&mut v14);
            perpetual_v3::market::add_fees_accrued_usd(v50, v49, v3);
            perpetual_v3::market::add_to_open_interest(v50, v21);
            perpetual_v3::events::emit_updated_open_interest_and_fees_accrued(v15, perpetual_v3::market::get_open_interest(v50), perpetual_v3::market::get_fees_accrued(v50));
        };
        v14
    }
    
    fun execute_liquidation<T0>(arg0: &mut ClearingHouse<T0>, arg1: &LiquidationReceipt, arg2: u256, arg3: u256, arg4: u256, arg5: u64, arg6: u64, arg7: &mut u256, arg8: &mut u256, arg9: &mut u256, arg10: &mut u256, arg11: &mut u256, arg12: &sui::object::ID) : (u256, u256) {
        let (v0, v1, v2, v3, v4, v5) = settle_liquidated_position<T0>(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg12);
        *arg11 = ifixed_v3::ifixed::add(*arg11, v1);
        if (v5) {
            *arg9 = ifixed_v3::ifixed::add(*arg9, v3);
            *arg10 = ifixed_v3::ifixed::add(*arg10, v4);
        } else {
            *arg7 = ifixed_v3::ifixed::add(*arg7, v3);
            *arg8 = ifixed_v3::ifixed::add(*arg8, v4);
        };
        if (ifixed_v3::ifixed::greater_than(v2, 0)) {
            distribute_debt<T0>(arg0, v2, arg2, v5, arg12);
        };
        (v0, v4)
    }
    
    fun fixed_price_to_orderbook_price(arg0: u256, arg1: u64, arg2: u64) : u64 {
        ifixed_v3::ifixed::to_balance(arg0, perpetual_v3::constants::b9_scaling()) / arg2 / perpetual_v3::constants::one_b9() / arg1
    }
    
    fun force_cancel_orders(arg0: &mut perpetual_v3::orderbook::Orderbook, arg1: u64, arg2: &vector<u128>, arg3: sui::object::ID) : (u64, u64) {
        let v0 = 0;
        let v1 = 0;
        let v2 = 0;
        while (v0 < std::vector::length<u128>(arg2)) {
            let v3 = *std::vector::borrow<u128>(arg2, v0);
            let v4 = perpetual_v3::orderbook::cancel_limit_order(arg0, arg1, v3);
            perpetual_v3::events::emit_canceled_order(arg3, arg1, v3, v4);
            if (perpetual_v3::order_id::is_ask(v3)) {
                v1 = v1 + v4;
            } else {
                v2 = v2 + v4;
            };
            v0 = v0 + 1;
        };
        (v1, v2)
    }
    
    fun get_base_and_quote_deltas(arg0: u64, arg1: u64, arg2: u64, arg3: u64) : (u256, u256) {
        (ifixed_v3::ifixed::from_balance(arg1 * arg2, perpetual_v3::constants::b9_scaling()), ifixed_v3::ifixed::from_u256balance((arg1 as u256) * (arg0 as u256) * (arg3 as u256), perpetual_v3::constants::b9_scaling()))
    }
    
    public(friend) fun get_best_price<T0>(arg0: &ClearingHouse<T0>, arg1: bool) : std::option::Option<u256> {
        let (v0, v1) = perpetual_v3::market::get_lot_tick_sizes(&arg0.market_params);
        best_price(get_orderbook<T0>(arg0), arg1, v0, v1)
    }
    
    public(friend) fun get_book_price<T0>(arg0: &ClearingHouse<T0>) : std::option::Option<u256> {
        let (v0, v1) = perpetual_v3::market::get_lot_tick_sizes(&arg0.market_params);
        book_price(get_orderbook<T0>(arg0), v0, v1)
    }
    
    public fun get_ch_version<T0>(arg0: &ClearingHouse<T0>) : u64 {
        arg0.version
    }
    
    fun get_collateral_symbol<T0>() : std::string::String {
        std::string::utf8(std::ascii::into_bytes(std::type_name::into_string(std::type_name::get<T0>())))
    }
    
    fun get_mark_price(arg0: &perpetual_v3::market::MarketState, arg1: &perpetual_v3::market::MarketParams, arg2: u256, arg3: u256, arg4: u64) : u256 {
        let v0 = perpetual_v3::market::calculate_funding_price(arg0, arg1, arg2, arg4);
        let v1 = ifixed_v3::ifixed::add(arg2, perpetual_v3::market::get_spread_twap(arg0));
        ifixed_v3::ifixed::max(ifixed_v3::ifixed::min(v1, v0), ifixed_v3::ifixed::min(ifixed_v3::ifixed::max(v1, v0), arg3))
    }
    
    public fun get_market_objects<T0>(arg0: &ClearingHouse<T0>) : (&perpetual_v3::market::MarketParams, &perpetual_v3::market::MarketState) {
        (&arg0.market_params, &arg0.market_state)
    }
    
    public(friend) fun get_market_objects_mut<T0>(arg0: &mut ClearingHouse<T0>) : (&perpetual_v3::market::MarketParams, &mut perpetual_v3::market::MarketState) {
        (&arg0.market_params, &mut arg0.market_state)
    }
    
    public fun get_market_params<T0>(arg0: &ClearingHouse<T0>) : &perpetual_v3::market::MarketParams {
        &arg0.market_params
    }
    
    public(friend) fun get_market_params_mut<T0>(arg0: &mut ClearingHouse<T0>) : &mut perpetual_v3::market::MarketParams {
        &mut arg0.market_params
    }
    
    public fun get_market_state<T0>(arg0: &ClearingHouse<T0>) : &perpetual_v3::market::MarketState {
        &arg0.market_state
    }
    
    public(friend) fun get_market_state_mut<T0>(arg0: &mut ClearingHouse<T0>) : &mut perpetual_v3::market::MarketState {
        &mut arg0.market_state
    }
    
    public fun get_market_vault<T0>(arg0: &ClearingHouse<T0>) : &Vault<T0> {
        sui::dynamic_field::borrow<perpetual_v3::keys::MarketVault, Vault<T0>>(&arg0.id, perpetual_v3::keys::market_vault())
    }
    
    public(friend) fun get_market_vault_mut<T0>(arg0: &mut ClearingHouse<T0>) : &mut Vault<T0> {
        sui::dynamic_field::borrow_mut<perpetual_v3::keys::MarketVault, Vault<T0>>(&mut arg0.id, perpetual_v3::keys::market_vault())
    }
    
    public fun get_orderbook<T0>(arg0: &ClearingHouse<T0>) : &perpetual_v3::orderbook::Orderbook {
        sui::dynamic_object_field::borrow<perpetual_v3::keys::Orderbook, perpetual_v3::orderbook::Orderbook>(&arg0.id, perpetual_v3::keys::market_orderbook())
    }
    
    public(friend) fun get_orderbook_mut<T0>(arg0: &mut ClearingHouse<T0>) : &mut perpetual_v3::orderbook::Orderbook {
        sui::dynamic_object_field::borrow_mut<perpetual_v3::keys::Orderbook, perpetual_v3::orderbook::Orderbook>(&mut arg0.id, perpetual_v3::keys::market_orderbook())
    }
    
    public fun get_position<T0>(arg0: &ClearingHouse<T0>, arg1: u64) : &perpetual_v3::position::Position {
        sui::dynamic_field::borrow<perpetual_v3::keys::Position, perpetual_v3::position::Position>(&arg0.id, perpetual_v3::keys::position(arg1))
    }
    
    public(friend) fun get_position_mut<T0>(arg0: &mut ClearingHouse<T0>, arg1: u64) : &mut perpetual_v3::position::Position {
        sui::dynamic_field::borrow_mut<perpetual_v3::keys::Position, perpetual_v3::position::Position>(&mut arg0.id, perpetual_v3::keys::position(arg1))
    }
    
    public fun get_vault_balances<T0>(arg0: &ClearingHouse<T0>) : (u64, u64) {
        let v0 = get_market_vault<T0>(arg0);
        (sui::balance::value<T0>(&v0.collateral_balance), sui::balance::value<T0>(&v0.insurance_fund_balance))
    }
    
    fun get_vault_collateral_balance<T0>(arg0: &Vault<T0>, arg1: u256) : u64 {
        sui::balance::value<T0>(&arg0.collateral_balance) - ifixed_v3::ifixed::to_balance(arg1, arg0.scaling_factor)
    }
    
    public fun get_vault_scaling_factor<T0>(arg0: &ClearingHouse<T0>) : u256 {
        get_market_vault<T0>(arg0).scaling_factor
    }
    
    public(friend) fun liquidate<T0>(arg0: &mut SessionHotPotato<T0>, arg1: u64, arg2: u64, arg3: &vector<u128>) {
        assert!(arg0.account_id != arg1, perpetual_v3::errors::self_liquidation());
        let (v0, v1) = perpetual_v3::market::get_lot_tick_sizes(&arg0.clearing_house.market_params);
        let v2 = get_orderbook_mut<T0>(&mut arg0.clearing_house);
        let v3 = &mut arg0.liquidation_receipt;
        let (_, _, v6) = perpetual_v3::orderbook::get_post_receipt_info(&arg0.post);
        assert!(std::vector::length<perpetual_v3::orderbook::FillReceipt>(&arg0.fills) == 0 && v6 == 0 && std::option::is_none<LiquidationReceipt>(v3), perpetual_v3::errors::liquidate_not_first_operation());
        let v7 = std::vector::length<u128>(arg3);
        let (v8, v9) = if (v7 != 0) {
            let (v10, v11) = force_cancel_orders(v2, arg1, arg3, sui::object::id<ClearingHouse<T0>>(&arg0.clearing_house));
            (v10, v11)
        } else {
            (0, 0)
        };
        let v12 = LiquidationReceipt{
            liqee_account_id  : arg1, 
            size_to_liquidate : arg2, 
            base_ask_cancel   : v8, 
            base_bid_cancel   : v9, 
            pending_orders    : v7,
        };
        std::option::fill<LiquidationReceipt>(v3, v12);
        arg0.book_price = book_price_or_index(v2, arg0.index_price, v0, v1);
    }
    
    public(friend) fun place_stop_order<T0>(arg0: ClearingHouse<T0>, arg1: &oracle_v3::oracle::PriceFeedStorage, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &sui::clock::Clock, arg4: perpetual_v3::account::StopOrderTicket<T0>, arg5: u64, arg6: bool, arg7: u256, arg8: bool, arg9: bool, arg10: u64, arg11: u64, arg12: u64, arg13: &vector<u8>) {
        let (v0, v1) = perpetual_v3::account::delete_stop_order_ticket<T0>(arg4, true);
        let v2 = v1;
        verify_encrypted_details(&v2, sui::object::id<ClearingHouse<T0>>(&arg0), arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13);
        assert!(sui::clock::timestamp_ms(arg3) < arg5, perpetual_v3::errors::stop_order_ticket_expired());
        let v3 = get_market_params<T0>(&arg0);
        check_oracle_price_feed_storages(v3, arg1, arg2);
        let v4 = perpetual_v3::oracle::get_price(arg1, arg3, perpetual_v3::market::get_oracle_tolerance(v3));
        let v5 = if (arg8 && v4 >= arg7) {
            true
        } else {
            let v6 = !arg8 && v4 < arg7;
            v6
        };
        assert!(v5, perpetual_v3::errors::stop_order_conditions_violated());
        let v7 = start_session<T0>(arg0, v0, arg1, arg2, arg3);
        if (arg6) {
            place_limit_order<T0>(&mut v7, arg9, arg10, arg11, arg12);
        } else {
            place_market_order<T0>(&mut v7, arg9, arg10);
        };
        share_clearing_house<T0>(end_session<T0>(v7));
    }
    
    fun process_fill_maker<T0>(arg0: &mut ClearingHouse<T0>, arg1: u256, arg2: u64, arg3: u64, arg4: u256, arg5: u256, arg6: u256, arg7: &perpetual_v3::orderbook::FillReceipt, arg8: &sui::object::ID) : (bool, u256, u256, u256, u256) {
        let (v0, v1, v2, v3) = perpetual_v3::orderbook::get_fill_receipt_info(arg7);
        let v4 = get_position_mut<T0>(arg0, v0);
        perpetual_v3::position::settle_position_funding(v4, arg1, arg5, arg6, arg8, v0);
        let (v5, _) = perpetual_v3::position::get_amounts(v4);
        let (v7, v8) = get_base_and_quote_deltas(perpetual_v3::order_id::price(v1), v2, arg2, arg3);
        let v9 = if (perpetual_v3::order_id::is_ask(v1)) {
            perpetual_v3::position::sub_from_pending_amount(v4, perpetual_v3::constants::ask(), v7);
            perpetual_v3::position::add_short_to_position(v4, v7, v8)
        } else {
            perpetual_v3::position::sub_from_pending_amount(v4, perpetual_v3::constants::bid(), v7);
            perpetual_v3::position::add_long_to_position(v4, v7, v8)
        };
        if (v3 == 0) {
            perpetual_v3::position::update_pending_orders(v4, false, 1);
        };
        let v10 = perpetual_v3::position::get_maker_fee(v4);
        if (v10 != perpetual_v3::constants::null_fee()) {
            arg4 = v10;
        };
        let v11 = ifixed_v3::ifixed::mul(arg4, v8);
        let (v12, v13) = perpetual_v3::position::get_amounts(v4);
        let (v14, v15) = perpetual_v3::position::get_pending_amounts(v4);
        let v16 = ifixed_v3::ifixed::sub(v9, v11);
        perpetual_v3::position::add_to_collateral_usd(v4, v16, arg1);
        perpetual_v3::events::emit_filled_maker_order(*arg8, v0, perpetual_v3::position::get_collateral(v4), v16, v1, v2, v3, v12, v13, v14, v15);
        (perpetual_v3::order_id::is_ask(v1), v7, v8, v11, ifixed_v3::ifixed::sub(ifixed_v3::ifixed::max(v12, 0), ifixed_v3::ifixed::max(v5, 0)))
    }
    
    fun process_fill_taker(arg0: &mut perpetual_v3::position::Position, arg1: u256, arg2: u64, arg3: u256, arg4: u256, arg5: u256, arg6: u256, arg7: u256, arg8: u256, arg9: &sui::object::ID) : (u256, u256) {
        let (v0, _) = perpetual_v3::position::get_amounts(arg0);
        let v2 = if (arg3 != 0) {
            perpetual_v3::position::add_short_to_position(arg0, arg3, arg4)
        } else {
            0
        };
        let v3 = if (arg5 != 0) {
            perpetual_v3::position::add_long_to_position(arg0, arg5, arg6)
        } else {
            0
        };
        let (v4, v5) = perpetual_v3::position::get_amounts(arg0);
        let v6 = perpetual_v3::position::get_taker_fee(arg0);
        if (v6 != perpetual_v3::constants::null_fee()) {
            arg7 = v6;
        };
        let v7 = ifixed_v3::ifixed::mul(arg7, ifixed_v3::ifixed::add(arg4, arg6));
        let v8 = v7;
        if (arg8 != 0) {
            v8 = ifixed_v3::ifixed::sub(v7, ifixed_v3::ifixed::mul(arg7, arg8));
        };
        let v9 = ifixed_v3::ifixed::sub(ifixed_v3::ifixed::add(v2, v3), v8);
        perpetual_v3::events::emit_filled_taker_order(*arg9, arg2, perpetual_v3::position::add_to_collateral_usd(arg0, v9, arg1), v9, arg3, arg4, arg5, arg6, v4, v5, arg8);
        (v8, ifixed_v3::ifixed::sub(ifixed_v3::ifixed::max(v4, 0), ifixed_v3::ifixed::max(v0, 0)))
    }
    
    fun process_post(arg0: &mut perpetual_v3::position::Position, arg1: u64, arg2: u64, arg3: u64, arg4: &perpetual_v3::orderbook::PostReceipt, arg5: &sui::object::ID) {
        let (v0, v1, v2) = perpetual_v3::orderbook::get_post_receipt_info(arg4);
        if (v2 == 0) {
            return
        };
        perpetual_v3::position::update_pending_orders(arg0, true, v2);
        let v3 = perpetual_v3::position::get_pending_orders_counter(arg0);
        assert!(v3 <= arg3, perpetual_v3::errors::max_pending_orders_exceeded());
        if (v0 != 0) {
            perpetual_v3::position::add_to_pending_amount(arg0, perpetual_v3::constants::ask(), ifixed_v3::ifixed::from_balance(v0 * arg2, perpetual_v3::constants::b9_scaling()));
        };
        if (v1 != 0) {
            perpetual_v3::position::add_to_pending_amount(arg0, perpetual_v3::constants::bid(), ifixed_v3::ifixed::from_balance(v1 * arg2, perpetual_v3::constants::b9_scaling()));
        };
        let (v4, v5) = perpetual_v3::position::get_pending_amounts(arg0);
        perpetual_v3::events::emit_posted_order(*arg5, arg1, v0, v1, v4, v5, v3);
    }
    
    public(friend) fun reject_position_fees_proposal<T0>(arg0: &mut ClearingHouse<T0>, arg1: &perpetual_v3::account::Account<T0>) {
        let v0 = perpetual_v3::account::get_account_id<T0>(arg1);
        let v1 = perpetual_v3::keys::position_fees_proposal(v0);
        assert!(sui::dynamic_field::exists_<perpetual_v3::keys::PositionFeesProposal>(&arg0.id, v1), perpetual_v3::errors::proposal_does_not_exist());
        let PositionFeesProposal {
            maker_fee : v2,
            taker_fee : v3,
        } = sui::dynamic_field::remove<perpetual_v3::keys::PositionFeesProposal, PositionFeesProposal>(&mut arg0.id, v1);
        perpetual_v3::events::emit_rejected_position_fees_proposal(sui::object::id<ClearingHouse<T0>>(arg0), v0, v2, v3);
    }
    
    public(friend) fun reset_position_fees<T0>(arg0: &mut ClearingHouse<T0>, arg1: u64) {
        perpetual_v3::position::update_position_fees(get_position_mut<T0>(arg0, arg1), perpetual_v3::constants::null_fee(), perpetual_v3::constants::null_fee());
        perpetual_v3::events::emit_resetted_position_fees(sui::object::id<ClearingHouse<T0>>(arg0), arg1);
    }
    
    fun settle_liquidated_position<T0>(arg0: &mut ClearingHouse<T0>, arg1: &LiquidationReceipt, arg2: u256, arg3: u256, arg4: u256, arg5: u64, arg6: u64, arg7: &sui::object::ID) : (u256, u256, u256, u256, u256, bool) {
        let (v0, v1) = get_market_objects<T0>(arg0);
        let (v2, v3, v4) = perpetual_v3::market::get_liquidation_fee_rates(v0);
        let (v5, v6) = perpetual_v3::market::get_lot_tick_sizes(v0);
        let v7 = perpetual_v3::market::get_margin_ratio_initial(v0);
        let (v8, v9) = perpetual_v3::market::get_cum_funding_rates(v1);
        let v10 = get_mark_price(v1, v0, arg3, arg4, arg5);
        let v11 = get_position_mut<T0>(arg0, arg1.liqee_account_id);
        perpetual_v3::position::settle_position_funding(v11, arg2, v8, v9, arg7, arg1.liqee_account_id);
        let (v12, v13) = perpetual_v3::position::compute_margin(v11, arg2, arg3, perpetual_v3::market::get_margin_ratio_maintenance(v0));
        assert!(ifixed_v3::ifixed::less_than(v12, v13), perpetual_v3::errors::position_above_mmr());
        perpetual_v3::position::sub_from_pending_amount(v11, perpetual_v3::constants::ask(), ifixed_v3::ifixed::from_balance(arg1.base_ask_cancel * v5, perpetual_v3::constants::b9_scaling()));
        perpetual_v3::position::sub_from_pending_amount(v11, perpetual_v3::constants::bid(), ifixed_v3::ifixed::from_balance(arg1.base_bid_cancel * v5, perpetual_v3::constants::b9_scaling()));
        perpetual_v3::position::update_pending_orders(v11, false, arg1.pending_orders);
        let (v14, v15) = perpetual_v3::position::get_pending_amounts(v11);
        assert!(v14 == 0 && v15 == 0 && perpetual_v3::position::get_pending_orders_counter(v11) == 0, perpetual_v3::errors::invalid_force_cancel_ids());
        let (v16, _) = perpetual_v3::position::get_amounts(v11);
        let v18 = sui::math::min(arg1.size_to_liquidate, ifixed_v3::ifixed::to_balance(v16, perpetual_v3::constants::b9_scaling()) / v5);
        let (v19, v20) = get_base_and_quote_deltas(fixed_price_to_orderbook_price(v10, v5, v6), v18, v5, v6);
        let (v21, v22) = if (!ifixed_v3::ifixed::is_neg(v16)) {
            (perpetual_v3::position::add_short_to_position(v11, v19, v20), ifixed_v3::ifixed::neg(v19))
        } else {
            (perpetual_v3::position::add_long_to_position(v11, v19, v20), 0)
        };
        let v23 = ifixed_v3::ifixed::mul(v4, v20);
        let v24 = ifixed_v3::ifixed::add(ifixed_v3::ifixed::mul(v3, v20), ifixed_v3::ifixed::mul(v2, ifixed_v3::ifixed::mul(ifixed_v3::ifixed::from_balance((arg1.base_ask_cancel + arg1.base_bid_cancel) * v5, perpetual_v3::constants::b9_scaling()), arg3)));
        let v25 = ifixed_v3::ifixed::sub(v21, ifixed_v3::ifixed::add(v24, v23));
        perpetual_v3::position::add_to_collateral_usd(v11, v25, arg2);
        let v26 = 0;
        let v27 = v19 == 0;
        let v28 = v27;
        if (ifixed_v3::ifixed::is_neg(perpetual_v3::position::get_collateral(v11))) {
            v26 = perpetual_v3::position::reset_collateral(v11);
            v28 = true;
        };
        let (v29, v30) = perpetual_v3::position::compute_margin(v11, arg2, arg3, v7);
        if (!v28) {
            let (v31, v32) = compute_and_set_tolerance_diff(perpetual_v3::market::get_liquidation_tolerance(v0), v7, v10, arg3, v3, v4, v5, v35, v19);
            assert!(ifixed_v3::ifixed::less_than(ifixed_v3::ifixed::add(v29, v31), ifixed_v3::ifixed::add(v30, v32)), perpetual_v3::errors::position_above_tolerance());
        };
        assert!(ifixed_v3::ifixed::greater_than_eq(v29, v30), perpetual_v3::errors::position_below_imr());
        let (v33, v34) = perpetual_v3::position::get_amounts(v11);
        transfer_from_vault_to_insurance_fund<T0>(get_market_vault_mut<T0>(arg0), perpetual_v3::market::get_fees_accrued(v1), ifixed_v3::ifixed::div(v23, arg2));
        perpetual_v3::events::emit_liquidated_position(*arg7, arg1.liqee_account_id, arg6, v35, v18, v10, v25, perpetual_v3::position::get_collateral(v11), v33, v34, v26);
        (v24, v22, v26, v19, v20, v35)
    }
    
    public(friend) fun share_clearing_house<T0>(arg0: ClearingHouse<T0>) {
        sui::transfer::share_object<ClearingHouse<T0>>(arg0);
    }
    
    fun socialize_debt(arg0: &mut perpetual_v3::market::MarketState, arg1: bool, arg2: u256, arg3: &sui::object::ID) {
        let v0 = perpetual_v3::market::get_open_interest(arg0);
        if (v0 != 0) {
            perpetual_v3::market::update_cum_fundings_side(arg0, arg3, !arg1, ifixed_v3::ifixed::div(arg2, v0));
            return
        };
    }
    
    public(friend) fun start_session<T0>(arg0: ClearingHouse<T0>, arg1: u64, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &oracle_v3::oracle::PriceFeedStorage, arg4: &sui::clock::Clock) : SessionHotPotato<T0> {
        let v0 = sui::object::id<ClearingHouse<T0>>(&arg0);
        let (v1, v2) = get_market_objects<T0>(&arg0);
        check_oracle_price_feed_storages(v1, arg2, arg3);
        let v3 = perpetual_v3::market::get_oracle_tolerance(v1);
        let v4 = perpetual_v3::oracle::get_price(arg3, arg4, v3);
        let v5 = perpetual_v3::oracle::get_price(arg2, arg4, v3);
        let (v6, v7) = perpetual_v3::market::get_cum_funding_rates(v2);
        let v8 = get_position_mut<T0>(&mut arg0, arg1);
        perpetual_v3::position::settle_position_funding(v8, v4, v6, v7, &v0, arg1);
        let (v9, v10) = perpetual_v3::position::compute_margin(v8, v4, v5, perpetual_v3::market::get_margin_ratio_initial(v1));
        SessionHotPotato<T0>{
            clearing_house      : arg0, 
            account_id          : arg1, 
            timestamp_ms        : sui::clock::timestamp_ms(arg4), 
            collateral_price    : v4, 
            index_price         : v5, 
            book_price          : 0, 
            margin_before       : v9, 
            min_margin_before   : v10, 
            fills               : std::vector::empty<perpetual_v3::orderbook::FillReceipt>(), 
            post                : perpetual_v3::orderbook::create_empty_post_receipt(), 
            liquidation_receipt : std::option::none<LiquidationReceipt>(),
        }
    }
    
    fun take_collateral<T0>(arg0: &mut ClearingHouse<T0>, arg1: &oracle_v3::oracle::PriceFeedStorage, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &sui::clock::Clock, arg4: u64, arg5: u64) : (sui::balance::Balance<T0>, u256, u64) {
        assert!(arg5 != 0, perpetual_v3::errors::deposit_or_withdraw_amount_zero());
        let v0 = sui::object::id<ClearingHouse<T0>>(arg0);
        let v1 = get_vault_scaling_factor<T0>(arg0);
        let (v2, v3) = get_market_objects<T0>(arg0);
        check_oracle_price_feed_storages(v2, arg1, arg2);
        let v4 = perpetual_v3::market::get_oracle_tolerance(v2);
        let v5 = perpetual_v3::oracle::get_price(arg2, arg3, v4);
        let (v6, v7) = perpetual_v3::market::get_cum_funding_rates(v3);
        let v8 = get_position_mut<T0>(arg0, arg4);
        perpetual_v3::position::settle_position_funding(v8, v5, v6, v7, &v0, arg4);
        assert!(ifixed_v3::ifixed::to_balance(perpetual_v3::position::compute_free_collateral(v8, v5, perpetual_v3::oracle::get_price(arg1, arg3, v4), perpetual_v3::market::get_margin_ratio_initial(v2)), v1) >= arg5, perpetual_v3::errors::insufficient_free_collateral());
        perpetual_v3::position::sub_from_collateral(v8, ifixed_v3::ifixed::from_balance(arg5, v1));
        let v9 = get_market_vault_mut<T0>(arg0);
        (sui::balance::split<T0>(&mut v9.collateral_balance, sui::math::min(arg5, get_vault_collateral_balance<T0>(v9, perpetual_v3::market::get_fees_accrued(v3)))), perpetual_v3::position::get_collateral(v8), sui::balance::value<T0>(&v9.collateral_balance))
    }
    
    fun ticks_per_lot_to_quote_per_base(arg0: u64, arg1: u64, arg2: u64) : u256 {
        ifixed_v3::ifixed::from_u256fraction((arg0 as u256) * (arg2 as u256), (arg1 as u256))
    }
    
    fun transfer_from_insurance_fund_to_vault<T0>(arg0: &mut Vault<T0>, arg1: u256) {
        sui::balance::join<T0>(&mut arg0.collateral_balance, sui::balance::split<T0>(&mut arg0.insurance_fund_balance, ifixed_v3::ifixed::to_balance(arg1, arg0.scaling_factor)));
    }
    
    fun transfer_from_vault_to_insurance_fund<T0>(arg0: &mut Vault<T0>, arg1: u256, arg2: u256) {
        sui::balance::join<T0>(&mut arg0.insurance_fund_balance, sui::balance::split<T0>(&mut arg0.collateral_balance, sui::math::min(get_vault_collateral_balance<T0>(arg0, arg1), ifixed_v3::ifixed::to_balance(arg2, arg0.scaling_factor))));
    }
    
    public(friend) fun update_clearing_house_version<T0>(arg0: &mut ClearingHouse<T0>) {
        arg0.version = perpetual_v3::constants::version();
        perpetual_v3::events::emit_updated_clearing_house_version(sui::object::id<ClearingHouse<T0>>(arg0), perpetual_v3::constants::version());
    }
    
    fun verify_encrypted_details(arg0: &vector<u8>, arg1: sui::object::ID, arg2: u64, arg3: bool, arg4: u256, arg5: bool, arg6: bool, arg7: u64, arg8: u64, arg9: u64, arg10: &vector<u8>) {
        let v0 = std::vector::empty<u8>();
        std::vector::append<u8>(&mut v0, sui::bcs::to_bytes<sui::object::ID>(&arg1));
        std::vector::append<u8>(&mut v0, sui::bcs::to_bytes<u64>(&arg2));
        std::vector::append<u8>(&mut v0, sui::bcs::to_bytes<bool>(&arg3));
        std::vector::append<u8>(&mut v0, sui::bcs::to_bytes<u256>(&arg4));
        std::vector::append<u8>(&mut v0, sui::bcs::to_bytes<bool>(&arg5));
        std::vector::append<u8>(&mut v0, sui::bcs::to_bytes<bool>(&arg6));
        std::vector::append<u8>(&mut v0, sui::bcs::to_bytes<u64>(&arg7));
        std::vector::append<u8>(&mut v0, sui::bcs::to_bytes<u64>(&arg8));
        std::vector::append<u8>(&mut v0, sui::bcs::to_bytes<u64>(&arg9));
        std::vector::append<u8>(&mut v0, *arg10);
        assert!(sui::hash::blake2b256(&v0) == *arg0, perpetual_v3::errors::wrong_order_details());
    }
    
    public(friend) fun withdraw_fees<T0>(arg0: &mut ClearingHouse<T0>, arg1: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        let v0 = get_market_vault_mut<T0>(arg0);
        let v1 = ifixed_v3::ifixed::to_balance(perpetual_v3::market::reset_fees_accrued(&mut arg0.market_state), v0.scaling_factor);
        assert!(v1 != 0, perpetual_v3::errors::no_fees_accrued());
        perpetual_v3::events::emit_withdrew_fees(sui::tx_context::sender(arg1), sui::object::id<ClearingHouse<T0>>(arg0), v1, sui::balance::value<T0>(&v0.collateral_balance));
        sui::coin::take<T0>(&mut v0.collateral_balance, v1, arg1)
    }
    
    public(friend) fun withdraw_insurance_fund<T0>(arg0: &mut ClearingHouse<T0>, arg1: &oracle_v3::oracle::PriceFeedStorage, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &sui::clock::Clock, arg4: u64, arg5: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        assert!(arg4 != 0, perpetual_v3::errors::deposit_or_withdraw_amount_zero());
        let v0 = &arg0.market_params;
        check_oracle_price_feed_storages(v0, arg1, arg2);
        let v1 = perpetual_v3::market::get_oracle_tolerance(v0);
        let v2 = perpetual_v3::oracle::get_price(arg2, arg3, v1);
        let v3 = get_market_vault_mut<T0>(arg0);
        let v4 = v3.scaling_factor;
        assert!(arg4 <= ifixed_v3::ifixed::to_balance(ifixed_v3::ifixed::div(ifixed_v3::ifixed::sub(ifixed_v3::ifixed::mul(ifixed_v3::ifixed::from_balance(sui::balance::value<T0>(&v3.insurance_fund_balance), v4), v2), ifixed_v3::ifixed::mul(perpetual_v3::constants::insurance_open_interest_fraction(), ifixed_v3::ifixed::mul(ifixed_v3::ifixed::abs(perpetual_v3::market::get_open_interest(&arg0.market_state)), perpetual_v3::oracle::get_price(arg1, arg3, v1)))), v2), v4), perpetual_v3::errors::insufficient_insurance_surplus());
        perpetual_v3::events::emit_withdrew_insurance_fund(sui::tx_context::sender(arg5), sui::object::id<ClearingHouse<T0>>(arg0), arg4, sui::balance::value<T0>(&v3.insurance_fund_balance));
        sui::coin::take<T0>(&mut v3.insurance_fund_balance, arg4, arg5)
    }
    
    // decompiled from Move bytecode v6
}

