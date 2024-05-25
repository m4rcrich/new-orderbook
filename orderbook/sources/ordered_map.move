module orderbook::bp_tree {
    use sui::dynamic_field as field;

    // === Errors ===

    const EKeyAlreadyExists: u64 = 0;



    const LEAF_FLAG: u64 = 0x8000_0000_0000_0000;

    public struct BPTree<phantom ValType: store> has key, store {
        id: UID,
        size: u64, // ??
        counter: u64,
        root: u64,
        first: u64, //??
        branch_min: u64,
        branch_max: u64,
        leaf_min: u64,
        leaf_max: u64,
    }

    public struct Node has drop, store {
        keys: vector<u128>,
        // node ids of children
        children: vector<u64>,
    }

    public struct Leaf<ValType: copy + drop + store> has store {
        keys_vals: vector<KeyVal<ValType>>,
        // id of next(adjacent) leaf
        next: u64,
    }

    public struct KeyVal<ValType: copy + drop + store> has copy, drop, store {
        key: u128,
        val: ValType,
    }


    public(package) fun empty<ValType: copy + drop + store>(branch_order: u64, leaf_order: u64, ctx: &mut TxContext) : BPTree<ValType> {
        let counter = 1;
        let root = LEAF_FLAG | counter;
        let mut bp_tree = BPTree<ValType>{
            id: object::new(ctx),
            size: 0,
            counter: 1,
            root : root,
            first : root,
            branch_min : branch_order,
            branch_max : 2 * branch_order,
            leaf_min : leaf_order,
            leaf_max: 2 * leaf_order,
        };
        let leaf = Leaf<ValType> {
            keys_vals : vector::empty<KeyVal<ValType>>(),
            next : 0,
        };
        field::add(&mut bp_tree.id, root, leaf);
        bp_tree
    }

    public(package) fun insert<ValType: copy + drop + store>(self: &mut BPTree<ValType>, key: u128, val: ValType) {
        let mut current = self.root;

        // while not a leaf
        while (current & LEAF_FLAG == 0) {
            let node = field::borrow<u64, Node>(&self.id, current);
            let child_index = binary_search(&node.keys, key);
            current = node.children[child_index];
        };

        let leaf = field::borrow_mut<u64, Leaf<ValType>>(&mut self.id, current);

        // insert val into leaf
        let (insert_index, found) = binary_search_leaf(&leaf.keys_vals, key);
        assert!(!found, EKeyAlreadyExists);

        let key_val = KeyVal<ValType> {
            key, 
            val,
        };
        leaf.keys_vals.insert(key_val, insert_index);

        self.size = self.size + 1;



        let counter = self.counter;


    }



    fun binary_search(keys: &vector<u128>, target: u128): u64 {
        let mut left = 0;
        let mut right = keys.length();
        while (left <= right) {
            let mid = (left + right) / 2;
            let key = keys[mid];
            if (key == target) {
                return mid + 1
            } else if (key < target) {
                left = mid + 1
            } else {
                right = mid - 1
            };
        };
        left
    }

    // returns (index, found)
    fun binary_search_leaf<ValType: copy + drop + store>(keys_vals : &vector<KeyVal<ValType>>, target_key: u128): (u64, bool) {
        let mut left = 0;
        let mut right = keys_vals.length();
        while (left <= right) {
            let mid = (left + right) / 2;
            let key = keys_vals[mid].key;
            if (key == target_key) {
                return (mid + 1, true)
            } else if (key < target_key) {
                left = mid + 1
            } else {
                right = mid - 1
            };
        };
        (left, false)
    }

}