#[test_only]
module orderbook::orderbook_test {
    use orderbook::orderbook::{Self, Orderbook, PostReceipt, add_to_post_receipt, best_price, book_price, cancel_limit_order, create_orderbook, fill_limit_order, fill_market_order, place_limit_order, place_market_order};
    use sui::test_scenario::{Self as test, ctx, Scenario, next_tx, end, TransactionEffects};
    use sui::test_utils::assert_eq;

    #[test] fun test_add_to_post_receipt() { let _ = test_add_to_post_receipt_(scenario()); }

    #[test] fun test_best_price() { let _ = test_best_price_(scenario()); }

    #[test] fun test_book_price() { let _ = test_book_price_(scenario()); }

    #[test] fun test_cancel_limit_order() { let _ = test_cancel_limit_order_(scenario()); }

    #[test] fun test_create_orderbook() { let _ = test_create_orderbook_(scenario()); }

    #[test] fun test_fill_limit_order() { let _ = test_fill_limit_order_(scenario()); }

    #[test] fun test_fill_market_order() { let _ = test_fill_market_order_(scenario()); }

    #[test] fun test_place_limit_order() { let _ = test_place_limit_order_(scenario()); }

    #[test] fun test_place_market_order() { let _ = test_place_market_order_(scenario()); }

    fun test_add_to_post_receipt_(mut test: Scenario): TransactionEffects {
        let (owner, _) = people();

        next_tx(&mut test, owner); {
            let mut post_receipt = create_empty_post_receipt();
            add_to_post_receipt(&mut post_receipt, true, 100);
            assert_eq(post_receipt.base_ask, 100);
            assert_eq(post_receipt.base_bid, 0);
            assert_eq(post_receipt.pending_orders, 1);

            add_to_post_receipt(&mut post_receipt, false, 50);
            assert_eq(post_receipt.base_ask, 100);
            assert_eq(post_receipt.base_bid, 50);
            assert_eq(post_receipt.pending_orders, 2);
        };

        end(test)
    }

    fun test_best_price_(mut test: Scenario): TransactionEffects {
        let (owner, _) = people();

        next_tx(&mut test, owner); {
            let mut orderbook = create_orderbook(10, 10, 10, 10, 10, 10, ctx(&mut test));
            place_limit_order(&mut orderbook, owner, true, 100, 10, orderbook::constants::post_only(), &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);
            place_limit_order(&mut orderbook, owner, false, 50, 5, orderbook::constants::post_only(), &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

            let best_ask = best_price(&orderbook, true);
            assert_eq(best_ask, std::option::some(10));

            let best_bid = best_price(&orderbook, false);
            assert_eq(best_bid, std::option::some(5));
        };

        end(test)
    }

    fun test_book_price_(mut test: Scenario): TransactionEffects {
        let (owner, _) = people();

        next_tx(&mut test, owner); {
            let mut orderbook = create_orderbook(10, 10, 10, 10, 10, 10, ctx(&mut test));
            place_limit_order(&mut orderbook, owner, true, 100, 10, orderbook::constants::post_only(), &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);
            place_limit_order(&mut orderbook, owner, false, 50, 5, orderbook::constants::post_only(), &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

            let book_price = book_price(&orderbook);
            assert_eq(book_price, std::option::some(7)); // Mid-price of 10 and 5
        };

        end(test)
    }

    fun test_cancel_limit_order_(mut test: Scenario): TransactionEffects {
        let (owner, _) = people();

        next_tx(&mut test, owner); {
            let mut orderbook = create_orderbook(10, 10, 10, 10, 10, 10, ctx(&mut test));
            let order_id = place_limit_order(&mut orderbook, owner, true, 100, 10, orderbook::constants::post_only(), &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

            let size = cancel_limit_order(&mut orderbook, owner, order_id);
            assert_eq(size, 100);

            let best_ask = best_price(&orderbook, true);
            assert_eq(best_ask, std::option::none());
        };

        end(test)
    }

    fun test_create_orderbook_(mut test: Scenario): TransactionEffects {
        let (owner, _) = people();

        next_tx(&mut test, owner); {
            let orderbook = create_orderbook(10, 10, 10, 10, 10, 10, ctx(&mut test));
            assert_eq(orderbook.counter, 0);
            assert_eq(orderbook::ordered_map::is_empty(orderbook.get_asks()), true);
            assert_eq(orderbook::ordered_map::is_empty(orderbook.get_bids()), true);
        };

        end(test)
    }

    fun test_fill_limit_order_(mut test: Scenario): TransactionEffects {
        let (owner, buyer) = people();

        next_tx(&mut test, owner); {
            let mut orderbook = create_orderbook(10, 10, 10, 10, 10, 10, ctx(&mut test));
            place_limit_order(&mut orderbook, owner, true, 100, 10, orderbook::constants::post_only(), &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

            let mut fill_receipts = vector::empty();
            let remaining_size = fill_limit_order(&mut orderbook, buyer, false, 50, 10, orderbook::constants::limit(), &mut fill_receipts);

            assert_eq(remaining_size, 0);
            assert_eq(vector::length(&fill_receipts), 1);
            assert_eq(fill_receipts[0].size, 50);

            let best_ask = best_price(&orderbook, true);
            assert_eq(best_ask, std::option::some(10)); // Remaining 50 at price 10
        };

        end(test)
    }

    fun test_fill_market_order_(mut test: Scenario): TransactionEffects {
        let (owner, buyer) = people();

        next_tx(&mut test, owner); {
            let mut orderbook = create_orderbook(10, 10, 10, 10, 10, 10, ctx(&mut test));
            place_limit_order(&mut orderbook, owner, true, 100, 10, orderbook::constants::post_only(), &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

            let mut fill_receipts = vector::empty();
            let remaining_size = fill_market_order(&mut orderbook, buyer, false, 50, &mut fill_receipts);

            assert_eq(remaining_size, 0);
            assert_eq(vector::length(&fill_receipts), 1);
            assert_eq(fill_receipts[0].size, 50);

            let best_ask = best_price(&orderbook, true);
            assert_eq(best_ask, std::option::some(10)); // Remaining 50 at price 10
        };

        end(test)
    }

    fun test_place_limit_order_(mut test: Scenario): TransactionEffects {
        let (owner, _) = people();

        next_tx(&mut test, owner); {
            let mut orderbook = create_orderbook(10, 10, 10, 10, 10, 10, ctx(&mut test));
            place_limit_order(&mut orderbook, owner, true, 100, 10, orderbook::constants::post_only(), &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

            let best_ask = best_price(&orderbook, true);
            assert_eq(best_ask, std::option::some(10));

            let best_bid = best_price(&orderbook, false);
            assert_eq(best_bid, std::option::none());
        };

        end(test)
    }

    fun test_place_market_order_(mut test: Scenario): TransactionEffects {
        let (owner, buyer) = people();

        next_tx(&mut test, owner); {
            let mut orderbook = create_orderbook(10, 10, 10, 10, 10, 10, ctx(&mut test));
            place_limit_order(&mut orderbook, owner, true, 100, 10, orderbook::constants::post_only(), &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

            let mut fill_receipts = vector::empty();
            place_market_order(&mut orderbook, buyer, false, 50, &mut fill_receipts);

            assert_eq(vector::length(&fill_receipts), 1);
            assert_eq(fill_receipts[0].size, 50);

            let best_ask = best_price(&orderbook, true);
            assert_eq(best_ask, std::option::some(10)); // Remaining 50 at price 10
        };

        end(test)
    }

    fun scenario(): Scenario { test::begin(@0x1) }
    fun people(): (address, address) { (@0xBEEF, @0x1337) }
}
