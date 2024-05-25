module perpetual_v3::interface {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};
    friend perpetual_v3::account;
    friend perpetual_v3::admin;
    friend perpetual_v3::clearing_house;
    friend perpetual_v3::constants;
    friend perpetual_v3::errors;
    friend perpetual_v3::events;
    friend perpetual_v3::keys;
    friend perpetual_v3::market;
    friend perpetual_v3::oracle;
    friend perpetual_v3::order_id;
    friend perpetual_v3::orderbook;
    friend perpetual_v3::ordered_map;
    friend perpetual_v3::position;
    friend perpetual_v3::registry;
    friend perpetual_v3::subaccount;

    public fun create_account<T0>(arg0: &mut perpetual_v3::registry::Registry, arg1: &mut sui::tx_context::TxContext) : perpetual_v3::account::Account<T0> {
        perpetual_v3::account::create_account<T0>(arg0, arg1)
    }
    
    public fun create_stop_order_ticket<T0>(arg0: &perpetual_v3::account::Account<T0>, arg1: address, arg2: vector<u8>, arg3: &mut sui::tx_context::TxContext) {
        perpetual_v3::account::create_stop_order_ticket<T0>(arg0, arg1, arg2, arg3);
    }
    
    public fun delete_stop_order_ticket<T0>(arg0: perpetual_v3::account::StopOrderTicket<T0>) {
        let (_, _) = perpetual_v3::account::delete_stop_order_ticket<T0>(arg0, false);
    }
    
    public fun deposit_collateral<T0>(arg0: &mut perpetual_v3::account::Account<T0>, arg1: sui::coin::Coin<T0>) {
        perpetual_v3::account::deposit_collateral<T0>(arg0, arg1);
    }
    
    public fun withdraw_collateral<T0>(arg0: &mut perpetual_v3::account::Account<T0>, arg1: u64, arg2: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        perpetual_v3::account::withdraw_collateral<T0>(arg0, arg1, arg2)
    }
    
    public fun accept_position_fees_proposal<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &perpetual_v3::account::Account<T0>) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        perpetual_v3::clearing_house::accept_position_fees_proposal<T0>(arg0, arg1);
    }
    
    public fun allocate_collateral<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &mut perpetual_v3::account::Account<T0>, arg2: u64) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        perpetual_v3::clearing_house::allocate_collateral<T0>(arg0, arg1, arg2);
    }
    
    public fun allocate_collateral_subaccount<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &mut perpetual_v3::subaccount::SubAccount<T0>, arg2: u64, arg3: &mut sui::tx_context::TxContext) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        assert!(sui::tx_context::sender(arg3) == perpetual_v3::subaccount::get_subaccount_user<T0>(arg1), perpetual_v3::errors::invalid_subaccount_user());
        perpetual_v3::clearing_house::allocate_collateral_subaccount<T0>(arg0, arg1, arg2);
    }
    
    public fun cancel_orders<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &perpetual_v3::account::Account<T0>, arg2: &vector<u128>) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        perpetual_v3::clearing_house::cancel_orders<T0>(arg0, perpetual_v3::account::get_account_id<T0>(arg1), arg2);
    }
    
    public fun commit_margin_ratios_proposal<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &sui::clock::Clock) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        perpetual_v3::clearing_house::commit_margin_ratios_proposal<T0>(arg0, arg1);
    }
    
    public fun create_clearing_house<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: perpetual_v3::orderbook::Orderbook, arg2: &sui::coin::CoinMetadata<T0>, arg3: &sui::clock::Clock, arg4: &oracle_v3::oracle::PriceFeedStorage, arg5: &oracle_v3::oracle::PriceFeedStorage, arg6: u256, arg7: u256, arg8: u64, arg9: u64, arg10: u64, arg11: u64, arg12: u64, arg13: u64, arg14: u256, arg15: u256, arg16: u256, arg17: u256, arg18: u256, arg19: u64, arg20: u64, arg21: &mut sui::tx_context::TxContext) : perpetual_v3::clearing_house::ClearingHouse<T0> {
        perpetual_v3::clearing_house::create_clearing_house<T0>(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21)
    }
    
    public fun create_margin_ratios_proposal<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: &sui::clock::Clock, arg3: u64, arg4: u256, arg5: u256) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        perpetual_v3::clearing_house::create_margin_ratios_proposal<T0>(arg1, arg2, arg3, arg4, arg5);
    }
    
    public fun create_market_position<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &perpetual_v3::account::Account<T0>) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        perpetual_v3::clearing_house::create_market_position<T0>(arg0, arg1);
    }
    
    public fun create_position_fees_proposal<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: u64, arg3: u256, arg4: u256) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        perpetual_v3::clearing_house::create_position_fees_proposal<T0>(arg1, arg2, arg3, arg4);
    }
    
    public fun deallocate_collateral<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &mut perpetual_v3::account::Account<T0>, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &oracle_v3::oracle::PriceFeedStorage, arg4: &sui::clock::Clock, arg5: u64) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        perpetual_v3::clearing_house::deallocate_collateral<T0>(arg0, arg1, arg2, arg3, arg4, arg5);
    }
    
    public fun deallocate_collateral_subaccount<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &mut perpetual_v3::subaccount::SubAccount<T0>, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &oracle_v3::oracle::PriceFeedStorage, arg4: &sui::clock::Clock, arg5: u64, arg6: &mut sui::tx_context::TxContext) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        assert!(sui::tx_context::sender(arg6) == perpetual_v3::subaccount::get_subaccount_user<T0>(arg1), perpetual_v3::errors::invalid_subaccount_user());
        perpetual_v3::clearing_house::deallocate_collateral_subaccount<T0>(arg0, arg1, arg2, arg3, arg4, arg5);
    }
    
    public fun delete_margin_ratios_proposal<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: &sui::clock::Clock) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        perpetual_v3::clearing_house::delete_margin_ratios_proposal<T0>(arg1, arg2);
    }
    
    public fun delete_position_fees_proposal<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: u64) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        perpetual_v3::clearing_house::delete_position_fees_proposal<T0>(arg1, arg2);
    }
    
    public fun donate_to_insurance_fund<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: sui::coin::Coin<T0>, arg2: &mut sui::tx_context::TxContext) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        perpetual_v3::clearing_house::donate_to_insurance_fund<T0>(arg0, arg1, sui::tx_context::sender(arg2));
    }
    
    public fun end_session<T0>(arg0: perpetual_v3::clearing_house::SessionHotPotato<T0>) : perpetual_v3::clearing_house::ClearingHouse<T0> {
        perpetual_v3::clearing_house::check_ch_version_in_session<T0>(&arg0);
        perpetual_v3::clearing_house::end_session<T0>(arg0)
    }
    
    public fun liquidate<T0>(arg0: &mut perpetual_v3::clearing_house::SessionHotPotato<T0>, arg1: u64, arg2: u64, arg3: &vector<u128>) {
        perpetual_v3::clearing_house::check_ch_version_in_session<T0>(arg0);
        perpetual_v3::clearing_house::liquidate<T0>(arg0, arg1, arg2, arg3);
    }
    
    public fun place_limit_order<T0>(arg0: &mut perpetual_v3::clearing_house::SessionHotPotato<T0>, arg1: bool, arg2: u64, arg3: u64, arg4: u64) {
        perpetual_v3::clearing_house::check_ch_version_in_session<T0>(arg0);
        perpetual_v3::clearing_house::place_limit_order<T0>(arg0, arg1, arg2, arg3, arg4);
    }
    
    public fun place_market_order<T0>(arg0: &mut perpetual_v3::clearing_house::SessionHotPotato<T0>, arg1: bool, arg2: u64) {
        perpetual_v3::clearing_house::check_ch_version_in_session<T0>(arg0);
        perpetual_v3::clearing_house::place_market_order<T0>(arg0, arg1, arg2);
    }
    
    public fun place_stop_order<T0>(arg0: perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &oracle_v3::oracle::PriceFeedStorage, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &sui::clock::Clock, arg4: perpetual_v3::account::StopOrderTicket<T0>, arg5: u64, arg6: bool, arg7: u256, arg8: bool, arg9: bool, arg10: u64, arg11: u64, arg12: u64, arg13: vector<u8>) {
        perpetual_v3::clearing_house::check_ch_version<T0>(&arg0);
        perpetual_v3::clearing_house::place_stop_order<T0>(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, &arg13);
    }
    
    public fun reject_position_fees_proposal<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &perpetual_v3::account::Account<T0>) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        perpetual_v3::clearing_house::reject_position_fees_proposal<T0>(arg0, arg1);
    }
    
    public fun reset_position_fees<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: u64) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        perpetual_v3::clearing_house::reset_position_fees<T0>(arg1, arg2);
    }
    
    public fun share_clearing_house<T0>(arg0: perpetual_v3::clearing_house::ClearingHouse<T0>) {
        perpetual_v3::clearing_house::share_clearing_house<T0>(arg0);
    }
    
    public fun start_session<T0>(arg0: perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &perpetual_v3::account::Account<T0>, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &oracle_v3::oracle::PriceFeedStorage, arg4: &sui::clock::Clock) : perpetual_v3::clearing_house::SessionHotPotato<T0> {
        perpetual_v3::clearing_house::check_ch_version<T0>(&arg0);
        perpetual_v3::clearing_house::start_session<T0>(arg0, perpetual_v3::account::get_account_id<T0>(arg1), arg2, arg3, arg4)
    }
    
    public fun withdraw_fees<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        perpetual_v3::clearing_house::withdraw_fees<T0>(arg1, arg2)
    }
    
    public fun withdraw_insurance_fund<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &oracle_v3::oracle::PriceFeedStorage, arg4: &sui::clock::Clock, arg5: u64, arg6: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        perpetual_v3::clearing_house::withdraw_insurance_fund<T0>(arg1, arg2, arg3, arg4, arg5, arg6)
    }
    
    public fun set_liquidation_tolerance<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: u64) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        let v0 = sui::object::id<perpetual_v3::clearing_house::ClearingHouse<T0>>(arg1);
        perpetual_v3::market::set_liquidation_tolerance(perpetual_v3::clearing_house::get_market_params_mut<T0>(arg1), &v0, arg2);
    }
    
    public fun set_max_pending_orders<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: u64) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        let v0 = sui::object::id<perpetual_v3::clearing_house::ClearingHouse<T0>>(arg1);
        perpetual_v3::market::set_max_pending_orders(perpetual_v3::clearing_house::get_market_params_mut<T0>(arg1), &v0, arg2);
    }
    
    public fun set_min_order_usd_value<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: u256) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        let v0 = sui::object::id<perpetual_v3::clearing_house::ClearingHouse<T0>>(arg1);
        perpetual_v3::market::set_min_order_usd_value(perpetual_v3::clearing_house::get_market_params_mut<T0>(arg1), &v0, arg2);
    }
    
    public fun set_oracle_tolerance<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: u64) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        let v0 = sui::object::id<perpetual_v3::clearing_house::ClearingHouse<T0>>(arg1);
        perpetual_v3::market::set_oracle_tolerance(perpetual_v3::clearing_house::get_market_params_mut<T0>(arg1), &v0, arg2);
    }
    
    public fun update_fees<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: u256, arg3: u256, arg4: u256, arg5: u256, arg6: u256) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        let v0 = sui::object::id<perpetual_v3::clearing_house::ClearingHouse<T0>>(arg1);
        perpetual_v3::market::update_fees(perpetual_v3::clearing_house::get_market_params_mut<T0>(arg1), &v0, arg2, arg3, arg4, arg5, arg6);
    }
    
    public fun update_funding_parameters<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: u64, arg3: u64, arg4: u64, arg5: u64) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        let v0 = sui::object::id<perpetual_v3::clearing_house::ClearingHouse<T0>>(arg1);
        perpetual_v3::market::update_funding_parameters(perpetual_v3::clearing_house::get_market_params_mut<T0>(arg1), &v0, arg2, arg3, arg4, arg5);
    }
    
    public fun update_spread_twap_parameters<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg2: u64, arg3: u64) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg1);
        let v0 = sui::object::id<perpetual_v3::clearing_house::ClearingHouse<T0>>(arg1);
        perpetual_v3::market::update_spread_twap_parameters(perpetual_v3::clearing_house::get_market_params_mut<T0>(arg1), &v0, arg2, arg3);
    }
    
    public fun create_orderbook(arg0: &perpetual_v3::admin::AdminCapability, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64, arg6: u64, arg7: &mut sui::tx_context::TxContext) : perpetual_v3::orderbook::Orderbook {
        perpetual_v3::orderbook::create_orderbook(arg1, arg2, arg3, arg4, arg5, arg6, arg7)
    }
    
    public fun register_market<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::registry::Registry, arg2: &perpetual_v3::clearing_house::ClearingHouse<T0>, arg3: u64) {
        perpetual_v3::registry::register_market<T0>(arg1, arg3, sui::object::id<perpetual_v3::clearing_house::ClearingHouse<T0>>(arg2));
    }
    
    public fun create_subaccount<T0>(arg0: &perpetual_v3::account::Account<T0>, arg1: address, arg2: &mut sui::tx_context::TxContext) {
        perpetual_v3::subaccount::create_subaccount<T0>(arg0, arg1, arg2);
    }
    
    public fun delete_subaccount<T0>(arg0: &perpetual_v3::account::Account<T0>, arg1: perpetual_v3::subaccount::SubAccount<T0>) {
        perpetual_v3::subaccount::delete_subaccount<T0>(arg0, arg1);
    }
    
    public fun set_subaccount_user<T0>(arg0: &perpetual_v3::account::Account<T0>, arg1: &mut perpetual_v3::subaccount::SubAccount<T0>, arg2: address) {
        perpetual_v3::subaccount::set_subaccount_user<T0>(arg0, arg1, arg2);
    }
    
    public fun cancel_orders_subaccount<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &perpetual_v3::subaccount::SubAccount<T0>, arg2: &vector<u128>, arg3: &mut sui::tx_context::TxContext) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        assert!(sui::tx_context::sender(arg3) == perpetual_v3::subaccount::get_subaccount_user<T0>(arg1), perpetual_v3::errors::invalid_subaccount_user());
        perpetual_v3::clearing_house::cancel_orders<T0>(arg0, perpetual_v3::subaccount::get_account_id<T0>(arg1), arg2);
    }
    
    public fun deposit_collateral_subaccount<T0>(arg0: &mut perpetual_v3::subaccount::SubAccount<T0>, arg1: sui::coin::Coin<T0>, arg2: &mut sui::tx_context::TxContext) {
        assert!(sui::tx_context::sender(arg2) == perpetual_v3::subaccount::get_subaccount_user<T0>(arg0), perpetual_v3::errors::invalid_subaccount_user());
        perpetual_v3::subaccount::deposit_collateral<T0>(arg0, arg1);
    }
    
    public fun start_session_subaccount<T0>(arg0: perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &perpetual_v3::subaccount::SubAccount<T0>, arg2: &oracle_v3::oracle::PriceFeedStorage, arg3: &oracle_v3::oracle::PriceFeedStorage, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) : perpetual_v3::clearing_house::SessionHotPotato<T0> {
        perpetual_v3::clearing_house::check_ch_version<T0>(&arg0);
        assert!(sui::tx_context::sender(arg5) == perpetual_v3::subaccount::get_subaccount_user<T0>(arg1), perpetual_v3::errors::invalid_subaccount_user());
        perpetual_v3::clearing_house::start_session<T0>(arg0, perpetual_v3::subaccount::get_account_id<T0>(arg1), arg2, arg3, arg4)
    }
    
    public fun update_funding<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &oracle_v3::oracle::PriceFeedStorage, arg2: &sui::clock::Clock) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        let v0 = sui::object::id<perpetual_v3::clearing_house::ClearingHouse<T0>>(arg0);
        let (v1, v2) = perpetual_v3::clearing_house::get_market_objects_mut<T0>(arg0);
        perpetual_v3::market::try_update_funding(v1, v2, arg1, arg2, &v0, perpetual_v3::clearing_house::get_book_price<T0>(arg0));
    }
    
    public fun update_twaps<T0>(arg0: &mut perpetual_v3::clearing_house::ClearingHouse<T0>, arg1: &oracle_v3::oracle::PriceFeedStorage, arg2: &sui::clock::Clock) {
        perpetual_v3::clearing_house::check_ch_version<T0>(arg0);
        let v0 = sui::object::id<perpetual_v3::clearing_house::ClearingHouse<T0>>(arg0);
        let (v1, v2) = perpetual_v3::clearing_house::get_market_objects_mut<T0>(arg0);
        perpetual_v3::market::try_update_twaps(v1, v2, arg1, arg2, &v0, perpetual_v3::clearing_house::get_book_price<T0>(arg0));
    }
    
    entry fun upgrade_clearing_house_version<T0>(arg0: &perpetual_v3::admin::AdminCapability, arg1: &mut perpetual_v3::clearing_house::ClearingHouse<T0>) {
        perpetual_v3::clearing_house::update_clearing_house_version<T0>(arg1);
    }
    
    public fun withdraw_collateral_subaccount<T0>(arg0: &perpetual_v3::account::Account<T0>, arg1: &mut perpetual_v3::subaccount::SubAccount<T0>, arg2: u64, arg3: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        perpetual_v3::subaccount::withdraw_collateral<T0>(arg0, arg1, arg2, arg3)
    }
    
    // decompiled from Move bytecode v6
}

