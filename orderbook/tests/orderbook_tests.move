// #[test_only]
// module orderbook::orderbook_test {
//     use orderbook::orderbook::{add_to_post_receipt, best_price, cancel_limit_order, create_orderbook, fill_limit_order, fill_market_order, place_limit_order, place_market_order, create_empty_post_receipt};
//     use sui::test_scenario::{Self as test, ctx, Scenario, next_tx, end, TransactionEffects};
//     use sui::test_utils::assert_eq;

//     const POST_ONLY: u64 = 1;
//     const FILL_OR_KILL: u64 = 2;
//     // const IMMEDIATE_OR_CANCEL: u64 = 3;

//     #[test] fun test_add_to_post_receipt() { let _ = test_add_to_post_receipt_(scenario()); }

//     #[test] fun test_cancel_limit_order() { let _ = test_cancel_limit_order_(scenario()); }

//     #[test] fun test_create_orderbook() { let _ = test_create_orderbook_(scenario()); }

//     #[test] fun test_fill_limit_order() { let _ = test_fill_limit_order_(scenario()); }

//     #[test] fun test_fill_market_order() { let _ = test_fill_market_order_(scenario()); }

//     #[test] fun test_place_limit_order() { let _ = test_place_limit_order_(scenario()); }

//     #[test] fun test_place_market_order() { let _ = test_place_market_order_(scenario()); }

//     fun test_add_to_post_receipt_(mut test: Scenario): TransactionEffects {
//         let (owner, _) = people();

//         next_tx(&mut test, owner); {
//             let mut post_receipt = create_empty_post_receipt();
//             add_to_post_receipt(&mut post_receipt, true, 100);
//             add_to_post_receipt(&mut post_receipt, false, 50);
//         };

//         end(test)
//     }

//     #[test]
//     fun test_place_limit_order_and_best_price() {
//         let mut test = scenario();
//         let (owner, _) = people();

//         next_tx(&mut test, owner); {
//             let mut orderbook = create_orderbook(10, 10, ctx(&mut test));
//             place_limit_order(
//                 &mut orderbook, 
//                 owner, 
//                 true, 
//                 100, 
//                 10, 
//                 POST_ONLY, 
//                 &mut vector::empty(), 
//                 &mut create_empty_post_receipt(), 
//                 &@0x1
//             );
//             place_limit_order(
//                 &mut orderbook, 
//                 owner, 
//                 false, 
//                 50, 
//                 5, 
//                 POST_ONLY, 
//                 &mut vector::empty(), 
//                 &mut create_empty_post_receipt(), 
//                 &@0x1
//             );

//             let best_ask = best_price(&orderbook, true);
//             assert_eq(best_ask, option::some(10));

//             let best_bid = best_price(&orderbook, false);
//             assert_eq(best_bid, option::some(5));
//         };

//         end(test);
//     }

//     fun test_cancel_limit_order_(mut test: Scenario): TransactionEffects {
//         let (owner, _) = people();

//         next_tx(&mut test, owner); {
//             let mut orderbook = create_orderbook(10, 10, ctx(&mut test));
//             let order_id = place_limit_order(&mut orderbook, owner, true, 100, 10, POST_ONLY, &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

//             let size = cancel_limit_order(&mut orderbook, owner, order_id);
//             assert_eq(size, 100);

//             let best_ask = best_price(&orderbook, true);
//             assert_eq(best_ask, std::option::none());
//         };

//         end(test)
//     }

//     fun test_create_orderbook_(mut test: Scenario): TransactionEffects {
//         let (owner, _) = people();

//         next_tx(&mut test, owner); {
//             let orderbook = create_orderbook(10, 10, ctx(&mut test));
//         };

//         end(test)
//     }

//     fun test_fill_limit_order_(mut test: Scenario): TransactionEffects {
//         let (owner, buyer) = people();

//         next_tx(&mut test, owner); {
//             let mut orderbook = create_orderbook(10, 10, ctx(&mut test));
//             place_limit_order(&mut orderbook, owner, true, 100, 10, POST_ONLY, &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

//             let mut fill_receipts = vector::empty();
//             let remaining_size = fill_limit_order(&mut orderbook, buyer, false, 50, 10, FILL_OR_KILL, &mut fill_receipts);

//             assert_eq(remaining_size, 0);
//             assert_eq(vector::length(&fill_receipts), 1);
//             let best_ask = best_price(&orderbook, true);
//             assert_eq(best_ask, std::option::some(10)); // Remaining 50 at price 10
//         };

//         end(test)
//     }

//     fun test_fill_market_order_(mut test: Scenario): TransactionEffects {
//         let (owner, buyer) = people();

//         next_tx(&mut test, owner); {
//             let mut orderbook = create_orderbook(10, 10, ctx(&mut test));
//             place_limit_order(&mut orderbook, owner, true, 100, 10, POST_ONLY, &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

//             let mut fill_receipts = vector::empty();
//             let remaining_size = fill_market_order(&mut orderbook, buyer, false, 50, &mut fill_receipts);

//             assert_eq(remaining_size, 0);
//             assert_eq(vector::length(&fill_receipts), 1);

//             let best_ask = best_price(&orderbook, true);
//             assert_eq(best_ask, std::option::some(10)); // Remaining 50 at price 10
//         };

//         end(test)
//     }

//     fun test_place_limit_order_(mut test: Scenario): TransactionEffects {
//         let (owner, _) = people();

//         next_tx(&mut test, owner); {
//             let mut orderbook = create_orderbook(10, 10, ctx(&mut test));
//             place_limit_order(&mut orderbook, owner, true, 100, 10, POST_ONLY, &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

//             let best_ask = best_price(&orderbook, true);
//             assert_eq(best_ask, std::option::some(10));

//             let best_bid = best_price(&orderbook, false);
//             assert_eq(best_bid, std::option::none());
//         };

//         end(test)
//     }

//     fun test_place_market_order_(mut test: Scenario): TransactionEffects {
//         let (owner, buyer) = people();

//         next_tx(&mut test, owner); {
//             let mut orderbook = create_orderbook(10, 10, ctx(&mut test));
//             place_limit_order(&mut orderbook, owner, true, 100, 10, POST_ONLY, &mut vector::empty(), &mut create_empty_post_receipt(), &@0x1);

//             let mut fill_receipts = vector::empty();
//             place_market_order(&mut orderbook, buyer, false, 50, &mut fill_receipts);

//             assert_eq(vector::length(&fill_receipts), 1);
//             let best_ask = best_price(&orderbook, true);
//             assert_eq(best_ask, std::option::some(10)); // Remaining 50 at price 10
//         };

//         end(test)
//     }

//     fun scenario(): Scenario { test::begin(@0x1) }
//     fun people(): (address, address) { (@0xBEEF, @0x1337) }
// }
