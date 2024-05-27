#[test_only]
module orderbook::bp_tree_tests {
    use orderbook::bp_tree;


    #[test]
    fun test() {
        let mut ctx = tx_context::dummy();

        let mut bp_tree = bp_tree::empty(1, 1, &mut ctx);
        bp_tree.insert(1, 1);
        bp_tree.insert(2, 2);
        bp_tree.insert(3, 3);
        bp_tree.insert(4, 4);
        bp_tree.insert(5, 5);
        bp_tree.insert(6, 6);
        bp_tree.insert(7, 7);
        bp_tree.insert(8, 8);
        bp_tree.insert(9, 9);


        let res = bp_tree.traverse_tree();

        // std::debug::print(&res);

        // assert!(res == vector[vector[2, 3], vector[1], vector[2], vector[3, 4]], 0); // for 4 keys
        assert!(res == vector[           vector[5],
                    vector[3],                                vector[7],
        vector[2],           vector[4],            vector[6],            vector[8],
  vector[1], vector[2], vector[3], vector[4], vector[5], vector[6], vector[7], vector[8,9]], 0);

        bp_tree.drop();
    }

}

