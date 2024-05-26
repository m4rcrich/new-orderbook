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
        children_min: u64,
        children_max: u64,
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


    public(package) fun empty<ValType: copy + drop + store>(children_order: u64, leaf_order: u64, ctx: &mut TxContext) : BPTree<ValType> {
        let root = LEAF_FLAG;
        let mut bp_tree = BPTree<ValType>{
            id: object::new(ctx),
            size: 0,
            counter: 1,
            root : root,
            first : root,
            children_min : children_order,
            children_max : 2 * children_order + 1,
            leaf_min : leaf_order,
            leaf_max: 2 * leaf_order,
        };
        let leaf = Leaf<ValType> {
            keys_vals : vector[],
            next : 0,
        };
        field::add(&mut bp_tree.id, root, leaf);
        bp_tree
    }

    public(package) fun insert<ValType: copy + drop + store>(self: &mut BPTree<ValType>, key: u128, val: ValType) {
        let mut current_id = self.root;
        let mut back_track_ids = vector[];
        let mut back_track_children_indexes = vector[];

        // while not a leaf
        while (current_id & LEAF_FLAG == 0) {
            let node = field::borrow<u64, Node>(&self.id, current_id);
            let child_index = binary_search(&node.keys, key);
            back_track_ids.push_back(current_id);
            back_track_children_indexes.push_back(child_index);
            current_id = node.children[child_index];
        };

        let leaf = field::borrow_mut<u64, Leaf<ValType>>(&mut self.id, current_id);

        // insert val into leaf
        let (insert_index, found) = binary_search_leaf(&leaf.keys_vals, key);
        assert!(!found, EKeyAlreadyExists);
        let key_val = KeyVal<ValType> {
            key,
            val,
        };
        leaf.keys_vals.insert(key_val, insert_index);
        self.size = self.size + 1;

        // if leaf is full then split
        if (leaf.keys_vals.length() > self.leaf_max) {
            // split leaf
            let new_leaf_id = LEAF_FLAG | self.counter;
            self.counter = self.counter + 1;
            leaf.next = new_leaf_id;
            let start_cut = leaf.keys_vals.length() / 2;
            let new_leaf = Leaf<ValType> {
                keys_vals: cut_right(&mut leaf.keys_vals, start_cut),
                next: leaf.next,
            };
            let mut mid_key = new_leaf.keys_vals[0].key;
            field::add(&mut self.id, new_leaf_id, new_leaf);

            let mut new_node_id = new_leaf_id;
            let mut add_root = true;

            while (back_track_ids.length() > 0) {
                let node_id = back_track_ids.pop_back();
                let node = field::borrow_mut<u64, Node>(&mut self.id, node_id);
                let child_index = back_track_children_indexes.pop_back();
                node.keys.insert(mid_key, child_index);
                node.children.insert(new_node_id, child_index + 1);

                // if node is full then split
                if (node.children.length() > self.children_max) {
                    // split node's children
                    let start_cut = node.children.length() / 2;
                    let new_node = Node {
                        keys: cut_right(&mut node.keys, start_cut + 1), // !!! CHECK "+1" !!!
                        children: cut_right(&mut node.children, start_cut),
                    };
                    mid_key = node.keys.pop_back();
                    new_node_id = self.counter;
                    self.counter = self.counter + 1;
                    field::add(&mut self.id, new_node_id, new_node);
                } else {
                    add_root = false;
                    break
                };
            };

            if (add_root) {
                let mut new_root_keys = vector[];
                new_root_keys.push_back(mid_key);

                let mut new_root_children = vector[];
                new_root_children.push_back(self.root);
                new_root_children.push_back(new_node_id);

                let new_root = Node{
                    keys : new_root_keys,
                    children : new_root_children,
                };
                self.root = self.counter;
                self.counter = self.counter + 1;
                field::add(&mut self.id, self.root, new_root);
            };

        }

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
                return (mid, true)
            } else if (key < target_key) {
                left = mid + 1
            } else {
                right = mid - 1
            };
        };
        (left, false)
    }

    fun cut_right<ValType: copy + drop + store>(vec: &mut vector<ValType>, cut_index: u64) : vector<ValType> {
        let mut result = vector[];
        let mut i = cut_index;
        while (i < vec.length()) {
            result.push_back(vec[i]);
            i = i + 1;
        };

        while (cut_index < vec.length()) {
            vec.pop_back();
        };

        result
    }

    #[test]
    fun cut_right_test() {
        let mut vec = vector[1, 2, 3, 4, 5, 6, 7];
        let result = cut_right(&mut vec, 3);
        assert!(vec == vector[1, 2, 3], 0);
        assert!(result == vector[4, 5, 6, 7], 0);
    }



}