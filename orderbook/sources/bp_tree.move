module orderbook::bp_tree {
    use sui::dynamic_field as field;

    // === Errors ===

    const EKeyAlreadyExists: u64 = 0;
    const EKeyNotFound: u64 = 1;

    const LEAF_FLAG: u64 = 0x8000_0000_0000_0000;

    public struct BPTree<phantom ValType: store> has key, store {
        id: UID,
        size: u64,
        counter: u64,
        root: u64,
        first: u64,
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

    public struct Leaf<ValType: copy + drop + store> has drop, store {
        keys_vals: vector<KeyVal<ValType>>,
        // id of next(adjacent) leaf
        next: u64,
    }

    public struct KeyVal<ValType: copy + drop + store> has copy, drop, store {
        key: u128,
        val: ValType,
    }

    // node_keys_min: min number of keys in a node, max number of keys in a node is 2 * node_keys_min, min number of children in a node is node_keys_min + 1, max number of children in a node is 2 * node_keys_min + 1
    // leaf_min: min number of keys in a leaf; max number of keys in a leaf is 2 * leaf_min
    public(package) fun empty<ValType: copy + drop + store>(node_keys_min: u64, leaf_min: u64, ctx: &mut TxContext): BPTree<ValType> {
        let root = LEAF_FLAG;
        let mut bp_tree = BPTree<ValType>{
            id: object::new(ctx),
            size: 0,
            counter: 1,
            root: root,
            first: root,
            children_min: node_keys_min + 1,
            children_max: 2 * node_keys_min + 1,
            leaf_min: leaf_min,
            leaf_max: 2 * leaf_min,
        };
        let leaf = Leaf<ValType> {
            keys_vals: vector[],
            next: 0,
        };
        field::add(&mut bp_tree.id, root, leaf);
        bp_tree
    }

    public(package) fun first_leaf_ptr<ValType: copy + drop + store>(self: &BPTree<ValType>): u64 {
        self.first
    }

    public(package) fun borrow_leaf<ValType: copy + drop + store>(self: &BPTree<ValType>, leaf_id: u64): &Leaf<ValType> {
        field::borrow<u64, Leaf<ValType>>(&self.id, leaf_id)
    }

    public(package) fun borrow_leaf_mut<ValType: copy + drop + store>(self: &mut BPTree<ValType>, leaf_id: u64): &mut Leaf<ValType> {
        field::borrow_mut<u64, Leaf<ValType>>(&mut self.id, leaf_id)
    }

    public(package) fun borrow_leaf_elem<ValType: copy + drop + store>(leaf: &Leaf<ValType>, index: u64): (u128, &ValType) {
        // let key_val = leaf.keys_vals.borrow(index);
        let key_val = &leaf.keys_vals[index];
        (key_val.key, &key_val.val)
    }

    public(package) fun borrow_leaf_elem_mut<ValType: copy + drop + store>(leaf: &mut Leaf<ValType>, index: u64): (u128, &mut ValType) {
        // let key_val = leaf.keys_vals.borrow_mut(index);
        let key_val = &mut leaf.keys_vals[index];
        (key_val.key, &mut key_val.val)
    }

    public(package) fun leaf_next<ValType: copy + drop + store>(leaf: &Leaf<ValType>): u64 {
        leaf.next
    }

    public(package) fun leaf_size<ValType: copy + drop + store>(leaf: &Leaf<ValType>): u64 {
        leaf.keys_vals.length()
    }

    public(package) fun leaf_keys<ValType: copy + drop + store>(leaf: &Leaf<ValType>): vector<u128> {
        let mut keys = vector<u128>[];
        let mut i = 0;
        while (i < leaf.keys_vals.length()) {
            keys.push_back(leaf.keys_vals[i].key);
            i = i + 1;
        };
        keys
    }

    public(package) fun insert<ValType: copy + drop + store>(self: &mut BPTree<ValType>, key: u128, val: ValType) {
        // std::debug::print(&std::string::utf8(b"insert"));
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
            // std::debug::print(&std::string::utf8(b"before split leaf"));
            // std::debug::print(&leaf.keys_vals);
            let cut_num = leaf.keys_vals.length() / 2;
            let new_leaf = Leaf<ValType> {
                keys_vals: cut_right(&mut leaf.keys_vals, cut_num),
                next: leaf.next,
            };
            // std::debug::print(&std::string::utf8(b"after split leaf"));
            // std::debug::print(&leaf.keys_vals);
            // std::debug::print(&new_leaf.keys_vals);
            let mut mid_key = leaf.keys_vals[leaf.keys_vals.length() - 1].key;
            field::add(&mut self.id, new_leaf_id, new_leaf);

            let mut new_node_id = new_leaf_id;
            let mut add_root = true;

            // std::debug::print(&back_track_ids);
            // std::debug::print(&back_track_children_indexes);

            while (back_track_ids.length() > 0) {
                let node_id = back_track_ids.pop_back();
                let node = field::borrow_mut<u64, Node>(&mut self.id, node_id);
                let child_index = back_track_children_indexes.pop_back();
                node.keys.insert(mid_key, child_index);
                node.children.insert(new_node_id, child_index + 1);

                // if node is full then split
                if (node.children.length() > self.children_max) {
                    // split node's children
                    // std::debug::print(&std::string::utf8(b"before split"));
                    // std::debug::print(&node.keys);
                    // std::debug::print(&node.children);
                    let cut_num = node.children.length() / 2;
                    let new_node = Node {
                        keys: cut_right(&mut node.keys, cut_num - 1),
                        children: cut_right(&mut node.children, cut_num),
                    };
                    // std::debug::print(&std::string::utf8(b"after split"));
                    // std::debug::print(&node.keys);
                    // std::debug::print(&new_node.keys);
                    // std::debug::print(&node.children);
                    // std::debug::print(&new_node.children);

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
                    keys: new_root_keys,
                    children: new_root_children,
                };
                self.root = self.counter;
                self.counter = self.counter + 1;
                field::add(&mut self.id, self.root, new_root);
            };

        }

    }

    public(package) fun batch_drop<ValType: copy + drop + store>(self: &mut BPTree<ValType>, mut key: u128, inclusive: bool) {
        if (!inclusive) {
            if (key == 0) return;
            key = key - 1;
        };

        let mut node_id = self.root;
        let mut is_key_present;
        let mut child_index_inclusive;
        let mut is_node;
        let mut dropped_children;
        let mut node;
        let mut remaining_size;
        let mut child_id;

        loop {
            if (node_id & LEAF_FLAG != 0) {
                batch_drop_from_leaf(self, node_id, key);
                return
            };
            node = field::borrow_mut<u64, Node>(&mut self.id, node_id);
            let child_index = binary_search(&node.keys, key);
            is_key_present = child_index < node.keys.length() && node.keys[child_index] == key;
            child_index_inclusive = if (is_key_present) {
                child_index + 1
            } else {
                child_index
            };
            child_id = node.children[child_index];
            is_node = child_id & LEAF_FLAG == 0;
            drop_left(&mut node.keys, child_index_inclusive);
            dropped_children = if (is_node) {
                cut_reversed_left(&mut node.children, child_index_inclusive)
            } else {
                drop_left(&mut node.children, child_index_inclusive);
                vector[]
            };
            remaining_size = node.keys.length() - child_index_inclusive;
            if (remaining_size == 0) {
                drop_children(self, child_index_inclusive, is_node, dropped_children);
                let mut removed_node = field::remove<u64, Node>(&mut self.id, node_id);
                node_id = removed_node.children.pop_back();
                self.root = node_id;
                if (is_key_present) return;
            } else break;
        };
        if (is_key_present) {
            drop_children(self, child_index_inclusive, is_node, dropped_children);
            return
        };
        let new_split_key = node.keys[0];
        let second_child = node.children[1];
        drop_children(self, child_index_inclusive, is_node, dropped_children);
        if (is_node) {
            let new_split_key_from_node = batch_drop_from_node(self, child_id, new_split_key, second_child, key);
            if (new_split_key_from_node != new_split_key) {
                let node = field::borrow_mut<u64, Node>(&mut self.id, node_id);
                if (new_split_key_from_node == 0) {
                    node.keys.remove(0);
                    node.children.remove(1);
                    if (remaining_size == 1) {
                        let mut removed_node = field::remove<u64, Node>(&mut self.id, node_id);
                        self.root = removed_node.children.pop_back();
                    };
                } else {
                    *node.keys.borrow_mut(0) = new_split_key_from_node;
                };
            };
            return
        } else {
            let remaining_leaf_size = batch_drop_from_leaf(self, child_id, key);
            if (remaining_leaf_size < self.leaf_min) {
                let new_split_key_from_leaf = migrate_to_left_leaf(self, child_id, remaining_leaf_size, second_child);
                let node = field::borrow_mut<u64, Node>(&mut self.id, node_id);
                if (new_split_key_from_leaf == 0) {
                    node.keys.remove(0);
                    node.children.remove(1);
                    if (remaining_size == 1) {
                        let mut removed_node = field::remove<u64, Node>(&mut self.id, node_id);
                        self.root = removed_node.children.pop_back();
                    };
                } else {
                    *node.keys.borrow_mut(0) = new_split_key_from_leaf;
                }
            };
        };
    }

    public(package) fun is_empty<ValType: copy + drop + store>(bp_tree: &BPTree<ValType>): bool {
        bp_tree.size == 0
    }

    public(package) fun remove<ValType: copy + drop + store>(self: &mut BPTree<ValType>, key: u128): ValType {
        let root = self.root;
        if (root & LEAF_FLAG == 0) {
            let (removed_val, remaining_size) = self.remove_from_node(root, key);
            if (remaining_size == 1) {
                let node = field::remove<u64, Node>(&mut self.id, root);
                self.root = node.children[0];
            };
            removed_val
        } else {
            let (removed_val, _) = self.remove_from_leaf(root, key);
            removed_val
        }
    }

    public(package) fun min_key<ValType: copy + drop + store>(bp_tree: &BPTree<ValType>): u128 {
        field::borrow<u64, Leaf<ValType>>(&bp_tree.id, bp_tree.first).keys_vals[0].key
    }

    public(package) fun max_key<ValType: copy + drop + store>(self: &BPTree<ValType>): u128 {
        let mut current_id = self.root;
        while (current_id & LEAF_FLAG == 0) {
            let node = field::borrow<u64, Node>(&self.id, current_id);
            current_id = node.children[node.children.length() - 1];
        };
        let leaf = field::borrow<u64, Leaf<ValType>>(&self.id, current_id);
        let key_val: &KeyVal<ValType> = &leaf.keys_vals[leaf.keys_vals.length() - 1];
        key_val.key
    }

    public(package) fun get_all_keys<ValType: copy + drop + store>(bp_tree: &BPTree<ValType>): vector<u128> {
        let mut current_leaf = field::borrow<u64, Leaf<ValType>>(&bp_tree.id, bp_tree.first);
        let mut keys = leaf_keys(current_leaf);

        loop {
            let next_leaf = field::borrow<u64, Leaf<ValType>>(&bp_tree.id, leaf_next(current_leaf));
            keys.append(leaf_keys(next_leaf));
            // Reached the end, last leaf points to itself
            if (next_leaf.next == current_leaf.next) break;
            current_leaf = next_leaf;
        };
        keys
    }

    fun remove_from_node<ValType: copy + drop + store>(self: &mut BPTree<ValType>, node_id: u64, key: u128): (ValType, u64) {
        let node = field::borrow<u64, Node>(&self.id, node_id);
        let node_keys = node.keys;
        let node_children = node.children;
        let mut keys_num = node_keys.length();
        let child_index = binary_search(&node.keys, key);
        let child_id = node.children[child_index];
        if (child_id & LEAF_FLAG == 0) {
            if (child_index < keys_num) { // not last child
                let (removed_val, remaining_size) = self.remove_from_node(child_id, key);
                if (remaining_size < self.children_min) {
                    let split_key = node_keys[child_index];
                    let from_id = node_children[child_index + 1];
                    let new_split_key = migrate_to_left_node(self, child_id, remaining_size, split_key, from_id);
                    update_after_migration(self, node_id, &mut keys_num, child_index, new_split_key);
                };
                (removed_val, keys_num + 1)
            } else { // last child
                let (removed_val, remaining_size) = self.remove_from_node(child_id, key);
                if (remaining_size < self.children_min) {
                    let prev_child_index = child_index - 1;
                    let split_key = node_keys[prev_child_index];
                    let from_id = node_children[prev_child_index];
                    let new_split_key = migrate_to_right_node(self, from_id, split_key, child_id, remaining_size);
                    update_after_migration_last(self, node_id, &mut keys_num, prev_child_index, new_split_key);
                };
                (removed_val, keys_num + 1)
            }
        } else {
            if (child_index < keys_num) { // not last child
                let (removed_val, remaining_size) = self.remove_from_leaf(child_id, key);
                if (remaining_size < self.leaf_min) {
                    let from_id = node_children[child_index + 1];
                    let new_split_key = migrate_to_left_leaf(self, child_id, remaining_size, from_id);
                    update_after_migration(self, node_id, &mut keys_num, child_index, new_split_key);
                };
                (removed_val, keys_num + 1)
            } else { // last child
                let (removed_val, remaining_size) = self.remove_from_leaf(child_id, key);
                if (remaining_size < self.leaf_min) {
                    let prev_child_index = child_index - 1;
                    let from_id = node_children[prev_child_index];
                    let new_split_key = migrate_to_right_leaf(self, from_id, child_id, remaining_size);
                    update_after_migration_last(self, node_id, &mut keys_num, prev_child_index, new_split_key);
                };
                (removed_val, keys_num + 1)
            }
        }
    }

    fun remove_from_leaf<ValType: copy + drop + store>(self: &mut BPTree<ValType>, leaf_id: u64, key: u128): (ValType, u64) {
        let leaf = field::borrow_mut<u64, Leaf<ValType>>(&mut self.id, leaf_id);
        let (index, found) = binary_search_leaf(&leaf.keys_vals, key);
        assert!(found, EKeyNotFound);
        let key_val = leaf.keys_vals.remove(index);
        self.size = self.size - 1;
        (key_val.val, leaf.keys_vals.length())
    }

    fun batch_drop_from_node<ValType: copy + drop + store>(self: &mut BPTree<ValType>, node_id: u64, mut split_key: u128, first_child: u64, key: u128): u128 {
        let node = field::borrow_mut<u64, Node>(&mut self.id, node_id);
        // let branch_keys = &branch.keys;
        // let branch_size = std::vector::length<u128>(branch_keys);
        let child_index = binary_search(&node.keys, key);
        let is_key_present = child_index < node.keys.length() && node.keys[child_index] == key;
        let child_index_inclusive = if (is_key_present) {
            child_index + 1
        } else {
            child_index
        };
        // let branch_kids = &mut branch.kids;
        // let kid_id = *std::vector::borrow_mut<u64>(branch_kids, kid_index);
        let child_id = node.children[child_index];
        let is_node = child_id & LEAF_FLAG == 0;
        drop_left(&mut node.keys, child_index_inclusive);
        let dropped_children = if (is_node) {
            cut_reversed_left(&mut node.children, child_index_inclusive)
        } else {
            drop_left(&mut node.children, child_index_inclusive);
            vector[]
        };
        let remaining_size = node.keys.length() - child_index_inclusive + 1;
        if (is_key_present) {
            if (remaining_size < self.children_min) {
                split_key = migrate_to_left_node(self, node_id, remaining_size, split_key, first_child);
            };
            drop_children(self, child_index_inclusive, is_node, dropped_children);
            return split_key
        };
        let (new_split_key, new_first_child ) = if (remaining_size <= self.children_min) {
            let (migrated_split_key, migrated_first_key, migrated_second_child) = migrate_to_left_node1(self, node_id, remaining_size, split_key, first_child);
            split_key = migrated_split_key;
            (migrated_first_key, migrated_second_child)
        } else {
            (node.keys[0], node.children[1])
        };
        drop_children(self, child_index_inclusive, is_node, dropped_children);
        if (is_node) {
            let new_split_key_from_node = batch_drop_from_node(self, child_id, new_split_key, new_first_child, key);
            if (new_split_key_from_node != new_split_key) {
                // let branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, branch_id);
                let node = field::borrow_mut<u64, Node>(&mut self.id, node_id);
                if (new_split_key_from_node == 0) {
                    // drop_first<u128>(&mut branch.keys);
                    node.keys.remove(0);
                    // drop_second<u64>(&mut branch.kids);
                    node.children.remove(1);
                } else {
                    // *std::vector::borrow_mut<u128>(&mut branch.keys, 0) = new_split_key_from_node;
                    *node.keys.borrow_mut(0) = new_split_key_from_node;
                };
            };
        } else {
            let remaining_leaf_size = batch_drop_from_leaf(self, child_id, key);
            if (remaining_leaf_size < self.leaf_min) {
                let new_split_key_from_leaf = migrate_to_left_leaf(self, child_id, remaining_leaf_size, new_first_child);
                // let branch = sui::dynamic_field::borrow_mut<u64, Node>(&mut self.id, node_id);
                let node = field::borrow_mut<u64, Node>(&mut self.id, node_id);
                if (new_split_key_from_leaf == 0) {
                    // drop_first<u128>(&mut branch.keys);
                    node.keys.remove(0);
                    // drop_second<u64>(&mut branch.kids);
                    node.children.remove(1);
                } else {
                    // *std::vector::borrow_mut<u128>(&mut branch.keys, 0) = new_split_key_from_leaf;
                    *node.keys.borrow_mut(0) = new_split_key_from_leaf;
                };
            };
        };
        split_key
    }

    fun batch_drop_from_leaf<ValType: copy + drop + store>(self: &mut BPTree<ValType>, leaf_id: u64, key: u128): u64 {
        let leaf = field::borrow_mut<u64, Leaf<ValType>>(&mut self.id, leaf_id);
        let (mut drop_index, found) = binary_search_leaf(&leaf.keys_vals, key);
        if (found) drop_index = drop_index + 1;
        drop_left(&mut leaf.keys_vals, drop_index);
        self.size = self.size - drop_index;
        leaf.keys_vals.length()
    }

    fun drop_children<ValType: copy + drop + store>(self: &mut BPTree<ValType>, mut drop_num: u64, is_node: bool, mut dropped_children: vector<u64>) {
        if (drop_num == 0) {
            return
        };
        if (is_node) {
            while (drop_num > 0) {
                drop_num = drop_num - 1;
                drop_node(self, dropped_children.pop_back());
            };
        } else {
            drop_first_leaves(self, drop_num);
        };
    }

    fun drop_node<ValType: copy + drop + store>(self: &mut BPTree<ValType>, node_id: u64) {
        let removed_node = field::remove<u64, Node>(&mut self.id, node_id);
        if (LEAF_FLAG & removed_node.children[0] == 0) {
            let mut i = 0;
            while (i < removed_node.children.length()) {
                drop_node(self, removed_node.children[i]);
                i = i + 1;
            };
        } else {
            drop_first_leaves(self, removed_node.children.length());
        };
    }

    fun drop_first_leaves<ValType: copy + drop + store>(self: &mut BPTree<ValType>, mut drop_num: u64) {
        let mut dropped_count = 0;
        let mut leaf_id = self.first;
        while (drop_num > 0) {
            let removed_leaf = field::remove<u64, Leaf<ValType>>(&mut self.id, leaf_id);
            dropped_count = dropped_count + removed_leaf.keys_vals.length();
            leaf_id = removed_leaf.next;
            drop_num = drop_num - 1;
        };
        self.size = self.size - dropped_count;
        self.first = leaf_id;
    }

    fun migrate_to_left_node<ValType: copy + drop + store>(self: &mut BPTree<ValType>, left_id: u64, left_size: u64, split_key: u128, right_id: u64): u128 {
        let right_node = field::borrow_mut<u64, Node>(&mut self.id, right_id);
        let merged_size = left_size + right_node.children.length();
        if (merged_size <= self.children_max) {
            merge_nodes(self, left_id, split_key, right_id);
            return 0
        };
        let migrate_count = (merged_size + 1) / 2 - left_size;
        let (new_split_key, migrated_keys) = cut_reversed_left1(&mut right_node.keys, migrate_count);
        let migrated_children = cut_reversed_left(&mut right_node.children, migrate_count);
        let left_node = field::borrow_mut<u64, Node>(&mut self.id, left_id);
        left_node.keys.push_back(split_key);
        append_reversed_right(&mut left_node.keys, migrated_keys);
        append_reversed_right(&mut left_node.children, migrated_children);
        new_split_key
    }

    fun migrate_to_left_node1<ValType: copy + drop + store>(self: &mut BPTree<ValType>, left_id: u64, left_size: u64, split_key: u128, right_id: u64): (u128, u128, u64) {
        let right_node = field::borrow_mut<u64, Node>(&mut self.id, right_id);
        let merged_size = left_size + right_node.children.length();
        if (merged_size <= self.children_max) {
            let Node {
                keys : right_keys,
                children : right_children,
            } = field::remove<u64, Node>(&mut self.id, right_id);
            let left_node = field::borrow_mut<u64, Node>(&mut self.id, left_id);
            left_node.keys.push_back(split_key);
            append_right(&mut left_node.keys, &right_keys);
            append_right(&mut left_node.children, &right_children);
            return (0, left_node.keys[0], left_node.children[1])
        };
        let migrate_count = (merged_size + 1) / 2 - left_size;
        let (new_split_key, migrated_keys) = cut_reversed_left1(&mut right_node.keys, migrate_count);
        let migrated_children = cut_reversed_left(&mut right_node.children, migrate_count);
        let left_node = field::borrow_mut<u64, Node>(&mut self.id, left_id);
        left_node.keys.push_back(split_key);
        append_reversed_right(&mut left_node.keys, migrated_keys);
        append_reversed_right(&mut left_node.children, migrated_children);
        (new_split_key, left_node.keys[0], left_node.children[1])
    }

    fun migrate_to_right_node<T: copy + drop + store>(self: &mut BPTree<T>, left_id: u64, split_key: u128, right_id: u64, right_size: u64): u128 {
        let left_node = field::borrow_mut<u64, Node>(&mut self.id, left_id);
        let merged_size = left_node.keys.length() + right_size;
        if (merged_size <= self.children_max) {
            merge_nodes(self, left_id, split_key, right_id);
            return 0
        };
        let migrate_count = merged_size / 2 - right_size;
        let mut migrated_keys = cut_right(&mut left_node.keys, migrate_count - 1);
        let migrated_children = cut_right(&mut left_node.children, migrate_count);
        let new_split_key = left_node.keys.pop_back();
        let right_node = field::borrow_mut<u64, Node>(&mut self.id, right_id);
        migrated_keys.push_back(split_key);
        append_left(migrated_keys, &mut right_node.keys);
        append_left(migrated_children, &mut right_node.children);
        new_split_key
    }

    fun merge_nodes<ValType: copy + drop + store>(self: &mut BPTree<ValType>, left_id: u64, split_key: u128, right_id: u64) {
        let Node {
            keys: right_keys,
            children: right_children,
        } = field::remove<u64, Node>(&mut self.id, right_id);
        let left_node = field::borrow_mut<u64, Node>(&mut self.id, left_id);
        left_node.keys.push_back(split_key);
        append_right(&mut left_node.keys, &right_keys);
        append_right(&mut left_node.children, &right_children);
    }

    fun migrate_to_left_leaf<ValType: copy + drop + store>(self: &mut BPTree<ValType>, left_id: u64, left_size: u64, right_id: u64): u128 {
        let right_leaf = field::borrow_mut<u64, Leaf<ValType>>(&mut self.id, right_id);
        let merged_size = left_size + right_leaf.keys_vals.length();
        if (merged_size <= self.leaf_max) {
            merge_leaves(self, left_id, right_id);
            return 0
        };
        let migrated_keys_vals = cut_reversed_left(&mut right_leaf.keys_vals, merged_size / 2 - left_size);
        let left_leaf = field::borrow_mut<u64, Leaf<ValType>>(&mut self.id, left_id);
        append_reversed_right(&mut left_leaf.keys_vals, migrated_keys_vals);
        left_leaf.keys_vals[left_leaf.keys_vals.length() - 1].key
    }

    fun migrate_to_right_leaf<ValType: copy + drop + store>(self: &mut BPTree<ValType>, left_id: u64, right_id: u64, right_size: u64): u128 {
        let left_leaf = field::borrow_mut<u64, Leaf<ValType>>(&mut self.id, left_id);
        let merged_size = left_leaf.keys_vals.length() + right_size;
        if (merged_size <= self.leaf_max) {
            merge_leaves(self, left_id, right_id);
            return 0
        };
        let migrated_keys_vals = cut_right(&mut left_leaf.keys_vals, merged_size / 2 - right_size);
        let last = left_leaf.keys_vals[left_leaf.keys_vals.length() - 1].key;
        let right_leaf = field::borrow_mut<u64, Leaf<ValType>>(&mut self.id, right_id);
        append_left(migrated_keys_vals, &mut right_leaf.keys_vals);
        last
    }

    fun merge_leaves<ValType: copy + drop + store>(self: &mut BPTree<ValType>, left_id: u64, right_id: u64) {
        let Leaf {
            keys_vals: right_keys_vals,
            next: right_next,
        } = field::remove<u64, Leaf<ValType>>(&mut self.id, right_id);
        let left_leaf = field::borrow_mut<u64, Leaf<ValType>>(&mut self.id, left_id);
        append_right(&mut left_leaf.keys_vals, &right_keys_vals);
        left_leaf.next = right_next;
    }

    fun update_after_migration<ValType: copy + drop + store>(self: &mut BPTree<ValType>, node_id: u64, keys_num: &mut u64, child_index: u64, new_split_key: u128) {
        let node = field::borrow_mut<u64, Node>(&mut self.id, node_id);
        if (new_split_key == 0) {
            node.keys.remove(child_index);
            node.children.remove(child_index + 1);
            *keys_num = *keys_num - 1;
            return
        };
        // node.keys[child_index] = new_split_key;
        *node.keys.borrow_mut(child_index) = new_split_key;
    }

    fun update_after_migration_last<ValType: copy + drop + store>(self: &mut BPTree<ValType>, node_id: u64, keys_num: &mut u64, child_index: u64, new_split_key: u128) {
        let node = field::borrow_mut<u64, Node>(&mut self.id, node_id);
        if (new_split_key == 0) {
            node.keys.pop_back();
            node.children.pop_back();
            *keys_num = *keys_num - 1;
            return
        };
        *node.keys.borrow_mut(child_index) = new_split_key;
    }

    fun binary_search(keys: &vector<u128>, target: u128): u64 {
        if (keys.length() == 0) {
            return 0
        };
        let mut left = 0;
        let mut right = keys.length() - 1;
        while (left <= right) {
            let mid = (left + right) / 2;
            let key = keys[mid];
            if (key == target) {
                return mid
            } else if (key < target) {
                left = mid + 1
            } else {
                if (mid == 0) return 0;
                right = mid - 1
            };
        };
        left
    }

    // returns (index, found)
    fun binary_search_leaf<ValType: copy + drop + store>(keys_vals: &vector<KeyVal<ValType>>, target_key: u128): (u64, bool) {
        if (keys_vals.length() == 0) {
            return (0, false)
        };
        let mut left = 0;
        let mut right = keys_vals.length() - 1;
        while (left <= right) {
            let mid = (left + right) / 2;
            let key = keys_vals[mid].key;
            if (key == target_key) {
                return (mid, true)
            } else if (key < target_key) {
                left = mid + 1
            } else {
                if (mid == 0) return (mid, false);
                right = mid - 1
            };
        };
        (left, false)
    }

    fun append_left<T: copy + drop + store>(left_vec: vector<T>, right_vec: &mut vector<T>) {
        let mut tmp = vector[];
        let mut i = 0;
        while (i < left_vec.length()) {
            tmp.push_back(left_vec[i]);
            i = i + 1;
        };
        i = 0;
        while (i < right_vec.length()) {
            tmp.push_back(right_vec[i]);
            i = i + 1;
        };
        *right_vec = tmp;
    }

    fun append_reversed_right<T0: copy + drop + store>(left_vec: &mut vector<T0>, mut right_vec: vector<T0>) {
        while (right_vec.length() > 0) {
            left_vec.push_back(right_vec.pop_back());
        };
    }

    fun append_right<T: copy + drop + store>(left_vec: &mut vector<T>, right_vec: &vector<T>) {
        let mut i = 0;
        while (i < right_vec.length()) {
            left_vec.push_back(right_vec[i]);
            i = i + 1;
        };
    }

    fun cut_reversed_left<T: copy + drop + store>(vec: &mut vector<T>, cut_num: u64): vector<T> {
        let mut result = vector[];
        let mut i = cut_num;
        while (i > 0) {
            i = i - 1;
            result.push_back(vec[i]);
        };
        drop_left(vec, cut_num);
        result
    }

    fun cut_reversed_left1<T: copy + drop + store>(vec: &mut vector<T>, cut_num: u64): (T, vector<T>) {
        let mut result = vector[];
        let cut_num_m1 = cut_num - 1;
        let mut i = cut_num_m1;
        while (i > 0) {
            i = i - 1;
            result.push_back(vec[i]);
        };
        let split_key = vec[cut_num_m1];
        drop_left(vec, cut_num);
        (split_key, result)
    }

    fun cut_right<T: copy + drop + store>(vec: &mut vector<T>, mut cut_num: u64): vector<T> {
        let mut result = vector[];
        let mut i = vec.length() - cut_num;
        while (i < vec.length()) {
            result.push_back(vec[i]);
            i = i + 1;
        };

        while (cut_num > 0) {
            vec.pop_back();
            cut_num = cut_num - 1;
        };

        result
    }

    fun drop_left<T: copy + drop + store>(vec: &mut vector<T>, mut drop_until: u64) {
        let mut tmp = vector[];
        while (drop_until < vec.length()) {
            tmp.push_back(vec[drop_until]);
            drop_until = drop_until + 1;
        };
        *vec = tmp;
    }

    #[test]
    fun cut_right_test() {
        let mut vec = vector[1, 2, 3, 4, 5, 6, 7];
        let result = cut_right(&mut vec, 4);
        assert!(vec == vector[1, 2, 3], 0);
        assert!(result == vector[4, 5, 6, 7], 0);
    }

    #[test]
    fun drop_left_test() {
        let mut vec = vector[1, 2, 3, 4, 5, 6, 7];
        drop_left(&mut vec, 4);
        assert!(vec == vector[5, 6, 7], 0);
    }

    #[test]
    fun drop_left_test2() {
        let mut vec = vector[1, 2, 3, 4, 5, 6, 7];
        drop_left(&mut vec, 2);
        assert!(vec == vector[3, 4, 5, 6, 7], 0);
    }

    #[test]
    fun append_left_test() {
        let vec = vector[1, 2, 3];
        let mut vec2 = vector[4, 5, 6];
        append_left(vec, &mut vec2);
        assert!(vec2 == vector[1, 2, 3, 4, 5, 6], 0);
    }

    #[test]
    fun append_right_test() {
        let mut vec = vector[1, 2, 3];
        let vec2 = vector[4, 5, 6];
        append_right(&mut vec, &vec2);
        assert!(vec == vector[1, 2, 3, 4, 5, 6], 0);
    }

    #[test_only]
    public fun traverse_tree<ValType: copy + drop + store>(self: &BPTree<ValType>): vector<vector<vector<u128>>> {
        let mut result = vector[];

        // BFS
        let mut queue = vector[self.root];

        while (queue.length() > 0) {
            let level_size = queue.length();
            let mut i = 0;
            let mut level = vector[];
            while (i < level_size) {
                let current_id = queue.remove(0);
                if (current_id & LEAF_FLAG == 0) {

                    let node = field::borrow<u64, Node>(&self.id, current_id);
                    let mut node_res = vector[];
                    let mut j = 0;
                    while (j < node.keys.length()) {
                        node_res.push_back(node.keys[j]);
                        j = j + 1;
                    };
                    level.push_back(node_res);
                    let mut j = 0;
                    while (j < node.children.length()) {
                        queue.push_back(node.children[j]);
                        j = j + 1;
                    };
                } else {
                    let leaf = field::borrow<u64, Leaf<ValType>>(&self.id, current_id);
                    let mut leaf_res = vector[];
                    let mut j = 0;
                    while (j < leaf.keys_vals.length()) {
                        leaf_res.push_back(leaf.keys_vals[j].key);
                        j = j + 1;
                    };
                    level.push_back(leaf_res);
                };
                i = i + 1;
            };
            result.push_back(level);
        };
        result
    }

    #[test_only]
    public fun check_tree(self: &BPTree<u64>): bool {
        self.check_tree_int(self.root, 0, 0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF)
    }

    #[test_only]
    fun check_tree_int(self: &BPTree<u64>, node_id: u64, min_key: u128, max_key: u128): bool {
        let is_leaf = (node_id & LEAF_FLAG != 0);
        if (is_leaf) {
            let leaf = field::borrow<u64, Leaf<u64>>(&self.id, node_id);
            let mut i = 0;
            while (i < leaf.keys_vals.length()) {
                if (leaf.keys_vals[i].key <= min_key || leaf.keys_vals[i].key > max_key) {
                    return false
                };
                if (i > 0 && leaf.keys_vals[i].key <= leaf.keys_vals[i - 1].key) {
                    return false
                };
                i = i + 1;
            };
            return true
        };

        let node = field::borrow<u64, Node>(&self.id, node_id);
        let mut i = 0;
        while (i < node.keys.length()) {
            if (node.keys[i] <= min_key || node.keys[i] > max_key) {
                return false
            };
            if (i > 0 && node.keys[i] <= node.keys[i - 1]) {
                return false
            };
            if (i == 0) {
                if (!check_tree_int(self, node.children[i], min_key, node.keys[i])) {
                    return false
                };
            } else {
                if (!check_tree_int(self, node.children[i], node.keys[i - 1], node.keys[i])) {
                    return false
                };
            };
            i = i + 1;
        };

        if (!check_tree_int(self, node.children[i], node.keys[i - 1], max_key)) {
            return false
        };

        true
    }

    #[test_only]
    public fun drop<ValType: copy + drop + store>(self: BPTree<ValType>) {
        let BPTree { id, size: _, counter: _, root: _, first: _, children_min: _, children_max: _, leaf_min: _, leaf_max: _ } = self;
        id.delete();
    }
}
