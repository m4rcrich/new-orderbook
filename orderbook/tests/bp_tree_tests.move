#[test_only]
module orderbook::bp_tree_tests {
    use orderbook::bp_tree;


    #[test]
    fun test_insert1() {
        let mut ctx = tx_context::dummy();

        let mut bp_tree = bp_tree::empty(1, 1, &mut ctx);
        bp_tree.insert(1, 1);
        bp_tree.insert(2, 2);
        bp_tree.insert(3, 3);
        bp_tree.insert(4, 4);

        let res = bp_tree.traverse_tree();
        assert!(res == vector[vector[2, 3], vector[1], vector[2], vector[3, 4]], 0);

        bp_tree.insert(5, 5);
        bp_tree.insert(6, 6);
        bp_tree.insert(7, 7);
        bp_tree.insert(8, 8);
        bp_tree.insert(9, 9);

        assert!(bp_tree.check_tree(), 0);

        let res = bp_tree.traverse_tree();
        // std::debug::print(&res);

        assert!(res == vector[           vector[5],
                    vector[3],                                vector[7],
        vector[2],           vector[4],            vector[6],            vector[8],
  vector[1], vector[2], vector[3], vector[4], vector[5], vector[6], vector[7], vector[8,9]], 0);

        bp_tree.drop();
    }

    #[test]
    fun test_insert2() {
        let mut ctx = tx_context::dummy();

        // example from https://www.youtube.com/watch?v=bJnoBLL8AAg
        let mut bp_tree = bp_tree::empty(2, 2, &mut ctx);
        bp_tree.insert(7, 7);
        bp_tree.insert(10, 10);
        bp_tree.insert(1, 1);
        bp_tree.insert(23, 23);
        bp_tree.insert(5, 5);
        bp_tree.insert(15, 15);
        bp_tree.insert(17, 17);
        bp_tree.insert(9, 9);
        bp_tree.insert(11, 11);
        bp_tree.insert(39, 39);
        bp_tree.insert(35, 35);
        bp_tree.insert(8, 8);
        bp_tree.insert(40, 40);
        bp_tree.insert(25, 25);


        assert!(bp_tree.check_tree(), 0);

        let res = bp_tree.traverse_tree();
        // std::debug::print(&res);

        assert!(res == vector[               vector[15],
                    vector[7,      9],                              vector[23,        35],
        vector[1, 5], vector[7,8], vector[9, 10, 11],     vector[15, 17], vector[23, 25], vector[35, 39, 40]], 0);

        bp_tree.drop();
    }

    #[test]
    fun test_remove() {
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
        // let res = bp_tree.traverse_tree();
        // std::debug::print(&res);

        bp_tree.remove(7);
        bp_tree.remove(5);

        // let res = bp_tree.traverse_tree();
        // std::debug::print(&res);

        assert!(bp_tree.check_tree(), 0);

        bp_tree.drop();
    }

    #[test]
    fun test_bptree_max_key() {
        let mut ctx = tx_context::dummy();
        let mut tree = bp_tree::empty<u64>(1, 1, &mut ctx);
        tree.insert(1, 1);
        tree.insert(2, 2);
        tree.insert(3, 3);
        tree.insert(4, 4);
        tree.insert(5, 5);
        tree.insert(6, 6);
        tree.insert(7, 7);
        tree.insert(8, 8);
        tree.insert(9, 9);

        let key = tree.max_key();
        assert!(key == 9, 0);
        tree.drop();
    }

    #[test]
    fun test_bptree_getallkeys() {
        let mut ctx = tx_context::dummy();
        let mut tree = bp_tree::empty<u64>(1, 1, &mut ctx);
        tree.insert(1, 1);
        tree.insert(2, 2);
        tree.insert(3, 3);
        tree.insert(4, 4);
        tree.insert(5, 5);
        tree.insert(6, 6);
        tree.insert(7, 7);
        tree.insert(8, 8);
        tree.insert(9, 9);

        let keys = tree.get_all_keys();
        assert!(keys == vector[1, 2, 3, 4, 5, 6, 7, 8, 9], 0);
        tree.drop();
    }
}

