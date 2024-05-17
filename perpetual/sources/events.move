#[allow(unused_variable)]
module perpetual_v3::events {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};
    friend perpetual_v3::account;
    friend perpetual_v3::admin;
    friend perpetual_v3::clearing_house;
    friend perpetual_v3::constants;
    friend perpetual_v3::errors;
    friend perpetual_v3::interface;
    friend perpetual_v3::keys;
    friend perpetual_v3::market;
    friend perpetual_v3::oracle;
    friend perpetual_v3::orderbook;
    friend perpetual_v3::order_id;
    friend perpetual_v3::ordered_map;
    friend perpetual_v3::position;
    friend perpetual_v3::registry;
    friend perpetual_v3::subaccount;

    struct CreatedAccount has copy, drop {
        user: address,
        account_id: u64,
    }
    
    struct DepositedCollateral has copy, drop {
        account_id: u64,
        collateral: u64,
        account_collateral_after: u64,
    }
    
    struct AllocatedCollateral has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        collateral: u64,
        account_collateral_after: u64,
        position_collateral_after: u256,
        vault_balance_after: u64,
    }
    
    struct WithdrewCollateral has copy, drop {
        account_id: u64,
        collateral: u64,
        account_collateral_after: u64,
    }
    
    struct DeallocatedCollateral has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        collateral: u64,
        account_collateral_after: u64,
        position_collateral_after: u256,
        vault_balance_after: u64,
    }
    
    struct CreatedOrderbook has copy, drop {
        branch_min: u64,
        branches_merge_max: u64,
        branch_max: u64,
        leaf_min: u64,
        leaves_merge_max: u64,
        leaf_max: u64,
    }
    
    struct CreatedClearingHouse has copy, drop {
        ch_id: sui::object::ID,
        collateral: std::string::String,
        coin_decimals: u64,
        margin_ratio_initial: u256,
        margin_ratio_maintenance: u256,
        base_oracle_id: sui::object::ID,
        collateral_oracle_id: sui::object::ID,
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
        lot_size: u64,
        tick_size: u64,
    }
    
    struct RegisteredClearingHouse has copy, drop {
        market_id: u64,
        ch_id: sui::object::ID,
        collateral_type: std::string::String,
    }
    
    struct UpdatedClearingHouseVersion has copy, drop {
        ch_id: sui::object::ID,
        version: u64,
    }
    
    struct UpdatedPremiumTwap has copy, drop {
        ch_id: sui::object::ID,
        book_price: u256,
        index_price: u256,
        premium_twap: u256,
        premium_twap_last_upd_ms: u64,
    }
    
    struct UpdatedSpreadTwap has copy, drop {
        ch_id: sui::object::ID,
        book_price: u256,
        index_price: u256,
        spread_twap: u256,
        spread_twap_last_upd_ms: u64,
    }
    
    struct UpdatedFunding has copy, drop {
        ch_id: sui::object::ID,
        cum_funding_rate_long: u256,
        cum_funding_rate_short: u256,
        funding_last_upd_ms: u64,
    }
    
    struct SettledFunding has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        collateral_change_usd: u256,
        collateral_after: u256,
        mkt_funding_rate_long: u256,
        mkt_funding_rate_short: u256,
    }
    
    struct FilledMakerOrder has copy, drop {
        ch_id: sui::object::ID,
        maker_account_id: u64,
        maker_collateral: u256,
        collateral_change_usd: u256,
        order_id: u128,
        maker_size: u64,
        maker_final_size: u64,
        maker_base_amount: u256,
        maker_quote_amount: u256,
        maker_pending_asks_quantity: u256,
        maker_pending_bids_quantity: u256,
    }
    
    struct FilledTakerOrder has copy, drop {
        ch_id: sui::object::ID,
        taker_account_id: u64,
        taker_collateral: u256,
        collateral_change_usd: u256,
        base_asset_delta_ask: u256,
        quote_asset_delta_ask: u256,
        base_asset_delta_bid: u256,
        quote_asset_delta_bid: u256,
        taker_base_amount: u256,
        taker_quote_amount: u256,
        liquidated_volume: u256,
    }
    
    struct OrderbookPostReceipt has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        order_id: u128,
        order_size: u64,
    }
    
    struct PostedOrder has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        posted_base_ask: u64,
        posted_base_bid: u64,
        pending_asks: u256,
        pending_bids: u256,
        pending_orders: u64,
    }
    
    struct CanceledOrder has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        size: u64,
        order_id: u128,
    }
    
    struct CanceledOrders has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        asks_quantity: u256,
        bids_quantity: u256,
        pending_orders: u64,
    }
    
    struct LiquidatedPosition has copy, drop {
        ch_id: sui::object::ID,
        liqee_account_id: u64,
        liqor_account_id: u64,
        is_liqee_long: bool,
        size_liquidated: u64,
        mark_price: u256,
        liqee_collateral_change_usd: u256,
        liqee_collateral: u256,
        liqee_base_amount: u256,
        liqee_quote_amount: u256,
        bad_debt: u256,
    }
    
    struct UpdatedCumFundings has copy, drop {
        ch_id: sui::object::ID,
        cum_funding_rate_long: u256,
        cum_funding_rate_short: u256,
    }
    
    struct CreatedPosition has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        mkt_funding_rate_long: u256,
        mkt_funding_rate_short: u256,
    }
    
    struct CreatedStopOrderTicket has copy, drop {
        account_id: u64,
        recipient: address,
        encrypted_details: vector<u8>,
    }
    
    struct DeletedStopOrderTicket has copy, drop {
        id: sui::object::ID,
        user_address: address,
        processed: bool,
    }
    
    struct CreatedMarginRatiosProposal has copy, drop {
        ch_id: sui::object::ID,
        margin_ratio_initial: u256,
        margin_ratio_maintenance: u256,
    }
    
    struct UpdatedMarginRatios has copy, drop {
        ch_id: sui::object::ID,
        margin_ratio_initial: u256,
        margin_ratio_maintenance: u256,
    }
    
    struct DeletedMarginRatiosProposal has copy, drop {
        ch_id: sui::object::ID,
        margin_ratio_initial: u256,
        margin_ratio_maintenance: u256,
    }
    
    struct CreatedPositionFeesProposal has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        maker_fee: u256,
        taker_fee: u256,
    }
    
    struct DeletedPositionFeesProposal has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        maker_fee: u256,
        taker_fee: u256,
    }
    
    struct AcceptedPositionFeesProposal has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        maker_fee: u256,
        taker_fee: u256,
    }
    
    struct RejectedPositionFeesProposal has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
        maker_fee: u256,
        taker_fee: u256,
    }
    
    struct ResettedPositionFees has copy, drop {
        ch_id: sui::object::ID,
        account_id: u64,
    }
    
    struct UpdatedFees has copy, drop {
        ch_id: sui::object::ID,
        maker_fee: u256,
        taker_fee: u256,
        liquidation_fee: u256,
        force_cancel_fee: u256,
        insurance_fund_fee: u256,
    }
    
    struct UpdatedFundingParameters has copy, drop {
        ch_id: sui::object::ID,
        funding_frequency_ms: u64,
        funding_period_ms: u64,
        premium_twap_frequency_ms: u64,
        premium_twap_period_ms: u64,
    }
    
    struct UpdatedSpreadTwapParameters has copy, drop {
        ch_id: sui::object::ID,
        spread_twap_frequency_ms: u64,
        spread_twap_period_ms: u64,
    }
    
    struct UpdatedMinOrderUsdValue has copy, drop {
        ch_id: sui::object::ID,
        min_order_usd_value: u256,
    }
    
    struct UpdatedLiquidationTolerance has copy, drop {
        ch_id: sui::object::ID,
        liquidation_tolerance: u64,
    }
    
    struct UpdatedOracleTolerance has copy, drop {
        ch_id: sui::object::ID,
        oracle_tolerance: u64,
    }
    
    struct UpdatedMaxPendingOrders has copy, drop {
        ch_id: sui::object::ID,
        max_pending_orders: u64,
    }
    
    struct DonatedToInsuranceFund has copy, drop {
        sender: address,
        ch_id: sui::object::ID,
        new_balance: u64,
    }
    
    struct WithdrewFees has copy, drop {
        sender: address,
        ch_id: sui::object::ID,
        amount: u64,
        vault_balance_after: u64,
    }
    
    struct WithdrewInsuranceFund has copy, drop {
        sender: address,
        ch_id: sui::object::ID,
        amount: u64,
        insurance_fund_balance_after: u64,
    }
    
    struct UpdatedOpenInterestAndFeesAccrued has copy, drop {
        ch_id: sui::object::ID,
        open_interest: u256,
        fees_accrued: u256,
    }
    
    struct CreatedSubAccount has copy, drop {
        subaccount_id: sui::object::ID,
        user: address,
        account_id: u64,
    }
    
    struct SetSubAccountUser has copy, drop {
        subaccount_id: sui::object::ID,
        user: address,
        account_id: u64,
    }
    
    struct DeletedSubAccount has copy, drop {
        subaccount_id: sui::object::ID,
        account_id: u64,
    }
    
    struct DepositedCollateralSubAccount has copy, drop {
        subaccount_id: sui::object::ID,
        account_id: u64,
        collateral: u64,
        subaccount_collateral_after: u64,
    }
    
    struct WithdrewCollateralSubAccount has copy, drop {
        subaccount_id: sui::object::ID,
        account_id: u64,
        collateral: u64,
        subaccount_collateral_after: u64,
    }
    
    struct AllocatedCollateralSubAccount has copy, drop {
        ch_id: sui::object::ID,
        subaccount_id: sui::object::ID,
        account_id: u64,
        collateral: u64,
        subaccount_collateral_after: u64,
        position_collateral_after: u256,
        vault_balance_after: u64,
    }
    
    struct DeallocatedCollateralSubAccount has copy, drop {
        ch_id: sui::object::ID,
        subaccount_id: sui::object::ID,
        account_id: u64,
        collateral: u64,
        subaccount_collateral_after: u64,
        position_collateral_after: u256,
        vault_balance_after: u64,
    }
    
    public(friend) fun emit_accepted_position_fees_proposal(arg0: sui::object::ID, arg1: u64, arg2: u256, arg3: u256) {
        let v0 = AcceptedPositionFeesProposal{
            ch_id      : arg0, 
            account_id : arg1, 
            maker_fee  : arg2, 
            taker_fee  : arg3,
        };
        sui::event::emit<AcceptedPositionFeesProposal>(v0);
    }
    
    public(friend) fun emit_allocated_collateral(arg0: sui::object::ID, arg1: u64, arg2: u64, arg3: u64, arg4: u256, arg5: u64) {
        let v0 = AllocatedCollateral{
            ch_id                     : arg0, 
            account_id                : arg1, 
            collateral                : arg2, 
            account_collateral_after  : arg3, 
            position_collateral_after : arg4, 
            vault_balance_after       : arg5,
        };
        sui::event::emit<AllocatedCollateral>(v0);
    }
    
    public(friend) fun emit_allocated_collateral_subaccount(arg0: sui::object::ID, arg1: sui::object::ID, arg2: u64, arg3: u64, arg4: u64, arg5: u256, arg6: u64) {
        let v0 = AllocatedCollateralSubAccount{
            ch_id                       : arg0, 
            subaccount_id               : arg1, 
            account_id                  : arg2, 
            collateral                  : arg3, 
            subaccount_collateral_after : arg4, 
            position_collateral_after   : arg5, 
            vault_balance_after         : arg6,
        };
        sui::event::emit<AllocatedCollateralSubAccount>(v0);
    }
    
    public(friend) fun emit_canceled_order(arg0: sui::object::ID, arg1: u64, arg2: u128, arg3: u64) {
        let v0 = CanceledOrder{
            ch_id      : arg0, 
            account_id : arg1, 
            size       : arg3, 
            order_id   : arg2,
        };
        sui::event::emit<CanceledOrder>(v0);
    }
    
    public(friend) fun emit_canceled_orders(arg0: sui::object::ID, arg1: u64, arg2: u256, arg3: u256, arg4: u64) {
        let v0 = CanceledOrders{
            ch_id          : arg0, 
            account_id     : arg1, 
            asks_quantity  : arg2, 
            bids_quantity  : arg3, 
            pending_orders : arg4,
        };
        sui::event::emit<CanceledOrders>(v0);
    }
    
    public(friend) fun emit_created_account(arg0: address, arg1: u64) {
        let v0 = CreatedAccount{
            user       : arg0, 
            account_id : arg1,
        };
        sui::event::emit<CreatedAccount>(v0);
    }
    
    public(friend) fun emit_created_clearing_house(arg0: sui::object::ID, arg1: std::string::String, arg2: u64, arg3: u256, arg4: u256, arg5: sui::object::ID, arg6: sui::object::ID, arg7: u64, arg8: u64, arg9: u64, arg10: u64, arg11: u64, arg12: u64, arg13: u256, arg14: u256, arg15: u256, arg16: u256, arg17: u256, arg18: u64, arg19: u64) {
        let v0 = CreatedClearingHouse{
            ch_id                     : arg0, 
            collateral                : arg1, 
            coin_decimals             : arg2, 
            margin_ratio_initial      : arg3, 
            margin_ratio_maintenance  : arg4, 
            base_oracle_id            : arg5, 
            collateral_oracle_id      : arg6, 
            funding_frequency_ms      : arg7, 
            funding_period_ms         : arg8, 
            premium_twap_frequency_ms : arg9, 
            premium_twap_period_ms    : arg10, 
            spread_twap_frequency_ms  : arg11, 
            spread_twap_period_ms     : arg12, 
            maker_fee                 : arg13, 
            taker_fee                 : arg14, 
            liquidation_fee           : arg15, 
            force_cancel_fee          : arg16, 
            insurance_fund_fee        : arg17, 
            lot_size                  : arg18, 
            tick_size                 : arg19,
        };
        sui::event::emit<CreatedClearingHouse>(v0);
    }
    
    public(friend) fun emit_created_margin_ratios_proposal(arg0: sui::object::ID, arg1: u256, arg2: u256) {
        let v0 = CreatedMarginRatiosProposal{
            ch_id                    : arg0, 
            margin_ratio_initial     : arg1, 
            margin_ratio_maintenance : arg2,
        };
        sui::event::emit<CreatedMarginRatiosProposal>(v0);
    }
    
    public(friend) fun emit_created_orderbook(arg0: u64, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) {
        let v0 = CreatedOrderbook{
            branch_min         : arg0, 
            branches_merge_max : arg1, 
            branch_max         : arg2, 
            leaf_min           : arg3, 
            leaves_merge_max   : arg4, 
            leaf_max           : arg5,
        };
        sui::event::emit<CreatedOrderbook>(v0);
    }
    
    public(friend) fun emit_created_position(arg0: sui::object::ID, arg1: u64, arg2: u256, arg3: u256) {
        let v0 = CreatedPosition{
            ch_id                  : arg0, 
            account_id             : arg1, 
            mkt_funding_rate_long  : arg2, 
            mkt_funding_rate_short : arg3,
        };
        sui::event::emit<CreatedPosition>(v0);
    }
    
    public(friend) fun emit_created_position_fees_proposal(arg0: sui::object::ID, arg1: u64, arg2: u256, arg3: u256) {
        let v0 = CreatedPositionFeesProposal{
            ch_id      : arg0, 
            account_id : arg1, 
            maker_fee  : arg2, 
            taker_fee  : arg3,
        };
        sui::event::emit<CreatedPositionFeesProposal>(v0);
    }
    
    public(friend) fun emit_created_stop_order_ticket(arg0: u64, arg1: address, arg2: vector<u8>) {
        let v0 = CreatedStopOrderTicket{
            account_id        : arg0, 
            recipient         : arg1, 
            encrypted_details : arg2,
        };
        sui::event::emit<CreatedStopOrderTicket>(v0);
    }
    
    public(friend) fun emit_created_subaccount(arg0: sui::object::ID, arg1: address, arg2: u64) {
        let v0 = CreatedSubAccount{
            subaccount_id : arg0, 
            user          : arg1, 
            account_id    : arg2,
        };
        sui::event::emit<CreatedSubAccount>(v0);
    }
    
    public(friend) fun emit_deallocated_collateral(arg0: sui::object::ID, arg1: u64, arg2: u64, arg3: u64, arg4: u256, arg5: u64) {
        let v0 = DeallocatedCollateral{
            ch_id                     : arg0, 
            account_id                : arg1, 
            collateral                : arg2, 
            account_collateral_after  : arg3, 
            position_collateral_after : arg4, 
            vault_balance_after       : arg5,
        };
        sui::event::emit<DeallocatedCollateral>(v0);
    }
    
    public(friend) fun emit_deallocated_collateral_subaccount(arg0: sui::object::ID, arg1: sui::object::ID, arg2: u64, arg3: u64, arg4: u64, arg5: u256, arg6: u64) {
        let v0 = DeallocatedCollateralSubAccount{
            ch_id                       : arg0, 
            subaccount_id               : arg1, 
            account_id                  : arg2, 
            collateral                  : arg3, 
            subaccount_collateral_after : arg4, 
            position_collateral_after   : arg5, 
            vault_balance_after         : arg6,
        };
        sui::event::emit<DeallocatedCollateralSubAccount>(v0);
    }
    
    public(friend) fun emit_deleted_margin_ratios_proposal(arg0: sui::object::ID, arg1: u256, arg2: u256) {
        let v0 = DeletedMarginRatiosProposal{
            ch_id                    : arg0, 
            margin_ratio_initial     : arg1, 
            margin_ratio_maintenance : arg2,
        };
        sui::event::emit<DeletedMarginRatiosProposal>(v0);
    }
    
    public(friend) fun emit_deleted_position_fees_proposal(arg0: sui::object::ID, arg1: u64, arg2: u256, arg3: u256) {
        let v0 = DeletedPositionFeesProposal{
            ch_id      : arg0, 
            account_id : arg1, 
            maker_fee  : arg2, 
            taker_fee  : arg3,
        };
        sui::event::emit<DeletedPositionFeesProposal>(v0);
    }
    
    public(friend) fun emit_deleted_stop_order_ticket(arg0: sui::object::ID, arg1: address, arg2: bool) {
        let v0 = DeletedStopOrderTicket{
            id           : arg0, 
            user_address : arg1, 
            processed    : arg2,
        };
        sui::event::emit<DeletedStopOrderTicket>(v0);
    }
    
    public(friend) fun emit_deleted_subaccount(arg0: sui::object::ID, arg1: u64) {
        let v0 = DeletedSubAccount{
            subaccount_id : arg0, 
            account_id    : arg1,
        };
        sui::event::emit<DeletedSubAccount>(v0);
    }
    
    public(friend) fun emit_deposited_collateral(arg0: u64, arg1: u64, arg2: u64) {
        let v0 = DepositedCollateral{
            account_id               : arg0, 
            collateral               : arg1, 
            account_collateral_after : arg2,
        };
        sui::event::emit<DepositedCollateral>(v0);
    }
    
    public(friend) fun emit_deposited_collateral_subaccount(arg0: sui::object::ID, arg1: u64, arg2: u64, arg3: u64) {
        let v0 = DepositedCollateralSubAccount{
            subaccount_id               : arg0, 
            account_id                  : arg1, 
            collateral                  : arg2, 
            subaccount_collateral_after : arg3,
        };
        sui::event::emit<DepositedCollateralSubAccount>(v0);
    }
    
    public(friend) fun emit_donated_to_insurance_fund(arg0: address, arg1: sui::object::ID, arg2: u64) {
        let v0 = DonatedToInsuranceFund{
            sender      : arg0, 
            ch_id       : arg1, 
            new_balance : arg2,
        };
        sui::event::emit<DonatedToInsuranceFund>(v0);
    }
    
    public(friend) fun emit_filled_maker_order(arg0: sui::object::ID, arg1: u64, arg2: u256, arg3: u256, arg4: u128, arg5: u64, arg6: u64, arg7: u256, arg8: u256, arg9: u256, arg10: u256) {
        let v0 = FilledMakerOrder{
            ch_id                       : arg0, 
            maker_account_id            : arg1, 
            maker_collateral            : arg2, 
            collateral_change_usd       : arg3, 
            order_id                    : arg4, 
            maker_size                  : arg5, 
            maker_final_size            : arg6, 
            maker_base_amount           : arg7, 
            maker_quote_amount          : arg8, 
            maker_pending_asks_quantity : arg9, 
            maker_pending_bids_quantity : arg10,
        };
        sui::event::emit<FilledMakerOrder>(v0);
    }
    
    public(friend) fun emit_filled_taker_order(arg0: sui::object::ID, arg1: u64, arg2: u256, arg3: u256, arg4: u256, arg5: u256, arg6: u256, arg7: u256, arg8: u256, arg9: u256, arg10: u256) {
        let v0 = FilledTakerOrder{
            ch_id                 : arg0, 
            taker_account_id      : arg1, 
            taker_collateral      : arg2, 
            collateral_change_usd : arg3, 
            base_asset_delta_ask  : arg4, 
            quote_asset_delta_ask : arg5, 
            base_asset_delta_bid  : arg6, 
            quote_asset_delta_bid : arg7, 
            taker_base_amount     : arg8, 
            taker_quote_amount    : arg9, 
            liquidated_volume     : arg10,
        };
        sui::event::emit<FilledTakerOrder>(v0);
    }
    
    public(friend) fun emit_liquidated_position(arg0: sui::object::ID, arg1: u64, arg2: u64, arg3: bool, arg4: u64, arg5: u256, arg6: u256, arg7: u256, arg8: u256, arg9: u256, arg10: u256) {
        let v0 = LiquidatedPosition{
            ch_id                       : arg0, 
            liqee_account_id            : arg1, 
            liqor_account_id            : arg2, 
            is_liqee_long               : arg3, 
            size_liquidated             : arg4, 
            mark_price                  : arg5, 
            liqee_collateral_change_usd : arg6, 
            liqee_collateral            : arg7, 
            liqee_base_amount           : arg8, 
            liqee_quote_amount          : arg9, 
            bad_debt                    : arg10,
        };
        sui::event::emit<LiquidatedPosition>(v0);
    }
    
    public(friend) fun emit_orderbook_post_receipt(arg0: sui::object::ID, arg1: u64, arg2: u128, arg3: u64) {
        let v0 = OrderbookPostReceipt{
            ch_id      : arg0, 
            account_id : arg1, 
            order_id   : arg2, 
            order_size : arg3,
        };
        sui::event::emit<OrderbookPostReceipt>(v0);
    }
    
    public(friend) fun emit_posted_order(arg0: sui::object::ID, arg1: u64, arg2: u64, arg3: u64, arg4: u256, arg5: u256, arg6: u64) {
        let v0 = PostedOrder{
            ch_id           : arg0, 
            account_id      : arg1, 
            posted_base_ask : arg2, 
            posted_base_bid : arg3, 
            pending_asks    : arg4, 
            pending_bids    : arg5, 
            pending_orders  : arg6,
        };
        sui::event::emit<PostedOrder>(v0);
    }
    
    public(friend) fun emit_registered_clearing_house(arg0: u64, arg1: sui::object::ID, arg2: std::string::String) {
        let v0 = RegisteredClearingHouse{
            market_id       : arg0, 
            ch_id           : arg1, 
            collateral_type : arg2,
        };
        sui::event::emit<RegisteredClearingHouse>(v0);
    }
    
    public(friend) fun emit_rejected_position_fees_proposal(arg0: sui::object::ID, arg1: u64, arg2: u256, arg3: u256) {
        let v0 = RejectedPositionFeesProposal{
            ch_id      : arg0, 
            account_id : arg1, 
            maker_fee  : arg2, 
            taker_fee  : arg3,
        };
        sui::event::emit<RejectedPositionFeesProposal>(v0);
    }
    
    public(friend) fun emit_resetted_position_fees(arg0: sui::object::ID, arg1: u64) {
        let v0 = ResettedPositionFees{
            ch_id      : arg0, 
            account_id : arg1,
        };
        sui::event::emit<ResettedPositionFees>(v0);
    }
    
    public(friend) fun emit_set_subaccount_user(arg0: sui::object::ID, arg1: address, arg2: u64) {
        let v0 = SetSubAccountUser{
            subaccount_id : arg0, 
            user          : arg1, 
            account_id    : arg2,
        };
        sui::event::emit<SetSubAccountUser>(v0);
    }
    
    public(friend) fun emit_settled_funding(arg0: sui::object::ID, arg1: u64, arg2: u256, arg3: u256, arg4: u256, arg5: u256) {
        let v0 = SettledFunding{
            ch_id                  : arg0, 
            account_id             : arg1, 
            collateral_change_usd  : arg2, 
            collateral_after       : arg3, 
            mkt_funding_rate_long  : arg4, 
            mkt_funding_rate_short : arg5,
        };
        sui::event::emit<SettledFunding>(v0);
    }
    
    public(friend) fun emit_updated_clearing_house_version(arg0: sui::object::ID, arg1: u64) {
        let v0 = UpdatedClearingHouseVersion{
            ch_id   : arg0, 
            version : arg1,
        };
        sui::event::emit<UpdatedClearingHouseVersion>(v0);
    }
    
    public(friend) fun emit_updated_cum_fundings(arg0: sui::object::ID, arg1: u256, arg2: u256) {
        let v0 = UpdatedCumFundings{
            ch_id                  : arg0, 
            cum_funding_rate_long  : arg1, 
            cum_funding_rate_short : arg2,
        };
        sui::event::emit<UpdatedCumFundings>(v0);
    }
    
    public(friend) fun emit_updated_fees(arg0: sui::object::ID, arg1: u256, arg2: u256, arg3: u256, arg4: u256, arg5: u256) {
        let v0 = UpdatedFees{
            ch_id              : arg0, 
            maker_fee          : arg1, 
            taker_fee          : arg2, 
            liquidation_fee    : arg3, 
            force_cancel_fee   : arg4, 
            insurance_fund_fee : arg5,
        };
        sui::event::emit<UpdatedFees>(v0);
    }
    
    public(friend) fun emit_updated_funding(arg0: sui::object::ID, arg1: u256, arg2: u256, arg3: u64) {
        let v0 = UpdatedFunding{
            ch_id                  : arg0, 
            cum_funding_rate_long  : arg1, 
            cum_funding_rate_short : arg2, 
            funding_last_upd_ms    : arg3,
        };
        sui::event::emit<UpdatedFunding>(v0);
    }
    
    public(friend) fun emit_updated_funding_parameters(arg0: sui::object::ID, arg1: u64, arg2: u64, arg3: u64, arg4: u64) {
        let v0 = UpdatedFundingParameters{
            ch_id                     : arg0, 
            funding_frequency_ms      : arg1, 
            funding_period_ms         : arg2, 
            premium_twap_frequency_ms : arg3, 
            premium_twap_period_ms    : arg4,
        };
        sui::event::emit<UpdatedFundingParameters>(v0);
    }
    
    public(friend) fun emit_updated_liquidation_tolerance(arg0: sui::object::ID, arg1: u64) {
        let v0 = UpdatedLiquidationTolerance{
            ch_id                 : arg0, 
            liquidation_tolerance : arg1,
        };
        sui::event::emit<UpdatedLiquidationTolerance>(v0);
    }
    
    public(friend) fun emit_updated_margin_ratios(arg0: sui::object::ID, arg1: u256, arg2: u256) {
        let v0 = UpdatedMarginRatios{
            ch_id                    : arg0, 
            margin_ratio_initial     : arg1, 
            margin_ratio_maintenance : arg2,
        };
        sui::event::emit<UpdatedMarginRatios>(v0);
    }
    
    public(friend) fun emit_updated_max_pending_orders(arg0: sui::object::ID, arg1: u64) {
        let v0 = UpdatedMaxPendingOrders{
            ch_id              : arg0, 
            max_pending_orders : arg1,
        };
        sui::event::emit<UpdatedMaxPendingOrders>(v0);
    }
    
    public(friend) fun emit_updated_min_order_usd_value(arg0: sui::object::ID, arg1: u256) {
        let v0 = UpdatedMinOrderUsdValue{
            ch_id               : arg0, 
            min_order_usd_value : arg1,
        };
        sui::event::emit<UpdatedMinOrderUsdValue>(v0);
    }
    
    public(friend) fun emit_updated_open_interest_and_fees_accrued(arg0: sui::object::ID, arg1: u256, arg2: u256) {
        let v0 = UpdatedOpenInterestAndFeesAccrued{
            ch_id         : arg0, 
            open_interest : arg1, 
            fees_accrued  : arg2,
        };
        sui::event::emit<UpdatedOpenInterestAndFeesAccrued>(v0);
    }
    
    public(friend) fun emit_updated_oracle_tolerance(arg0: sui::object::ID, arg1: u64) {
        let v0 = UpdatedOracleTolerance{
            ch_id            : arg0, 
            oracle_tolerance : arg1,
        };
        sui::event::emit<UpdatedOracleTolerance>(v0);
    }
    
    public(friend) fun emit_updated_premium_twap(arg0: sui::object::ID, arg1: u256, arg2: u256, arg3: u256, arg4: u64) {
        let v0 = UpdatedPremiumTwap{
            ch_id                    : arg0, 
            book_price               : arg1, 
            index_price              : arg2, 
            premium_twap             : arg3, 
            premium_twap_last_upd_ms : arg4,
        };
        sui::event::emit<UpdatedPremiumTwap>(v0);
    }
    
    public(friend) fun emit_updated_spread_twap(arg0: sui::object::ID, arg1: u256, arg2: u256, arg3: u256, arg4: u64) {
        let v0 = UpdatedSpreadTwap{
            ch_id                   : arg0, 
            book_price              : arg1, 
            index_price             : arg2, 
            spread_twap             : arg3, 
            spread_twap_last_upd_ms : arg4,
        };
        sui::event::emit<UpdatedSpreadTwap>(v0);
    }
    
    public(friend) fun emit_updated_spread_twap_parameters(arg0: sui::object::ID, arg1: u64, arg2: u64) {
        let v0 = UpdatedSpreadTwapParameters{
            ch_id                    : arg0, 
            spread_twap_frequency_ms : arg1, 
            spread_twap_period_ms    : arg2,
        };
        sui::event::emit<UpdatedSpreadTwapParameters>(v0);
    }
    
    public(friend) fun emit_withdrew_collateral(arg0: u64, arg1: u64, arg2: u64) {
        let v0 = WithdrewCollateral{
            account_id               : arg0, 
            collateral               : arg1, 
            account_collateral_after : arg2,
        };
        sui::event::emit<WithdrewCollateral>(v0);
    }
    
    public(friend) fun emit_withdrew_collateral_subaccount(arg0: sui::object::ID, arg1: u64, arg2: u64, arg3: u64) {
        let v0 = WithdrewCollateralSubAccount{
            subaccount_id               : arg0, 
            account_id                  : arg1, 
            collateral                  : arg2, 
            subaccount_collateral_after : arg3,
        };
        sui::event::emit<WithdrewCollateralSubAccount>(v0);
    }
    
    public(friend) fun emit_withdrew_fees(arg0: address, arg1: sui::object::ID, arg2: u64, arg3: u64) {
        let v0 = WithdrewFees{
            sender              : arg0, 
            ch_id               : arg1, 
            amount              : arg2, 
            vault_balance_after : arg3,
        };
        sui::event::emit<WithdrewFees>(v0);
    }
    
    public(friend) fun emit_withdrew_insurance_fund(arg0: address, arg1: sui::object::ID, arg2: u64, arg3: u64) {
        let v0 = WithdrewInsuranceFund{
            sender                       : arg0, 
            ch_id                        : arg1, 
            amount                       : arg2, 
            insurance_fund_balance_after : arg3,
        };
        sui::event::emit<WithdrewInsuranceFund>(v0);
    }
    
    // decompiled from Move bytecode v6
}

