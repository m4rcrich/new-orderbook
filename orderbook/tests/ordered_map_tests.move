#[test_only]
module orderbook::ordered_map_tests {
    //TODO: rework once ordered_map is more defined
    use orderbook::bp_tree::{Self, BPTree, Node, Leaf, KeyVal, check_tree_struct, check_empty_tree};
    use sui::test_utils::assert_eq;

    #[test]
    fun test_insert() {
        let ctx = &mut tx_context::dummy();
        let mut tree1 = bp_tree::empty<u64>(2, 2, ctx);
        
        bp_tree::insert(&mut tree1, 48, 48);
        bp_tree::insert(&mut tree1, 16, 16);
        bp_tree::insert(&mut tree1, 1, 1);
        bp_tree::insert(&mut tree1, 3, 3);

        let x = vector<u64>[48, 16, 1, 3];
 
        let is_equal = bp_tree::check_tree_struct(&tree1, 
            x,
            1,
            1 //not sure how root is instantiated, todo change this
        );   
        assert_eq(is_equal,true);     
    }

    #[test]
    fun test_delete() {
        let ctx = &mut tx_context::dummy();
        let mut tree1 = bp_tree::empty<u64>(2, 2, ctx);
        
        bp_tree::insert(&mut tree1, 48, 48);
        bp_tree::insert(&mut tree1, 16, 16);
        bp_tree::insert(&mut tree1, 1, 1);
        bp_tree::insert(&mut tree1, 3, 3);
        bp_tree::delete(&mut tree1, 48, 48);
        bp_tree::delete(&mut tree1, 16, 16);
        bp_tree::delete(&mut tree1, 1, 1);
        bp_tree::delete(&mut tree1, 3, 3);

        let is_equal = bp_tree::check_empty_tree(&tree1);
        assert_eq(is_equal,true); 
    }

}