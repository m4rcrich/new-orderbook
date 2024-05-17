#[allow(unused_variable)]
module perpetual_v3::keys {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};
    friend perpetual_v3::account;
    friend perpetual_v3::admin;
    friend perpetual_v3::clearing_house;
    friend perpetual_v3::constants;
    friend perpetual_v3::errors;
    friend perpetual_v3::events;
    friend perpetual_v3::interface;
    friend perpetual_v3::market;
    friend perpetual_v3::oracle;
    friend perpetual_v3::order_id;
    friend perpetual_v3::orderbook;
    friend perpetual_v3::ordered_map;
    friend perpetual_v3::position;
    friend perpetual_v3::registry;
    friend perpetual_v3::subaccount;

    struct Registry has copy, drop, store {
        market_id: u64,
    }
    
    struct Orderbook has copy, drop, store {
        dummy_field: bool,
    }
    
    struct MarketVault has copy, drop, store {
        dummy_field: bool,
    }
    
    struct Position has copy, drop, store {
        account_id: u64,
    }
    
    struct MarginRatioProposal has copy, drop, store {
        dummy_field: bool,
    }
    
    struct PositionFeesProposal has copy, drop, store {
        account_id: u64,
    }
    
    struct AsksMap has copy, drop, store {
        dummy_field: bool,
    }
    
    struct BidsMap has copy, drop, store {
        dummy_field: bool,
    }
    
    public(friend) fun asks_map() : AsksMap {
        AsksMap{dummy_field: false}
    }
    
    public(friend) fun bids_map() : BidsMap {
        BidsMap{dummy_field: false}
    }
    
    public(friend) fun margin_ratio_proposal() : MarginRatioProposal {
        MarginRatioProposal{dummy_field: false}
    }
    
    public(friend) fun market_orderbook() : Orderbook {
        Orderbook{dummy_field: false}
    }
    
    public(friend) fun market_vault() : MarketVault {
        MarketVault{dummy_field: false}
    }
    
    public(friend) fun position(arg0: u64) : Position {
        Position{account_id: arg0}
    }
    
    public(friend) fun position_fees_proposal(arg0: u64) : PositionFeesProposal {
        PositionFeesProposal{account_id: arg0}
    }
    
    public(friend) fun registry(arg0: u64) : Registry {
        Registry{market_id: arg0}
    }
    
    // decompiled from Move bytecode v6
}

