#[allow(unused_variable)]
module perpetual_v3::ordered_map {
    use ifixed_v3::ifixed::{Self};
    use oracle_v3::oracle::{Self};
    friend perpetual_v3::account;
    friend perpetual_v3::admin;
    friend perpetual_v3::clearing_house;
    friend perpetual_v3::constants;
    friend perpetual_v3::errors;
    friend perpetual_v3::events;
    friend perpetual_v3::interface;
    friend perpetual_v3::keys;
    friend perpetual_v3::market;
    friend perpetual_v3::oracle;
    friend perpetual_v3::order_id;
    friend perpetual_v3::orderbook;
    friend perpetual_v3::position;
    friend perpetual_v3::registry;
    friend perpetual_v3::subaccount;
    
    struct Map<phantom T0: copy + drop + store> has store, key {
        id: sui::object::UID,
        size: u64,
        counter: u64,
        root: u64,
        first: u64,
        branch_min: u64,
        branches_merge_max: u64,
        branch_max: u64,
        leaf_min: u64,
        leaves_merge_max: u64,
        leaf_max: u64,
    }
    
    struct Branch has drop, store {
        keys: vector<u128>,
        kids: vector<u64>,
    }
    
    struct Pair<T0: copy + drop + store> has copy, drop, store {
        key: u128,
        val: T0,
    }
    
    struct Leaf<T0: copy + drop + store> has drop, store {
        keys_vals: vector<Pair<T0>>,
        next: u64,
    }
    
    public(friend) fun borrow<T0: copy + drop + store>(map: &Map<T0>, key: u128) : &T0 {
        let leaf = &sui::dynamic_field::borrow<u64, Leaf<T0>>(&map.id, find_leaf<T0>(map, key)).keys_vals;
        let pair = std::vector::borrow<Pair<T0>>(leaf, binary_search_p<T0>(leaf, std::vector::length<Pair<T0>>(leaf), key));
        assert!(key == pair.key, perpetual_v3::errors::key_not_exist());
        &pair.val
    }
    
    public(friend) fun borrow_mut<T0: copy + drop + store>(map: &mut Map<T0>, key: u128) : &mut T0 {
        let leaf = sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut map.id, find_leaf<T0>(map, key));
        let leaf_keys_vals = &leaf.keys_vals;
        let pair = std::vector::borrow_mut<Pair<T0>>(&mut leaf.keys_vals, binary_search_p<T0>(leaf_keys_vals, std::vector::length<Pair<T0>>(leaf_keys_vals), key));
        assert!(key == pair.key, perpetual_v3::errors::key_not_exist());
        &mut pair.val
    }
    
    public(friend) fun destroy_empty<T0: copy + drop + store>(map: Map<T0>) {
        assert!(is_empty<T0>(&map), perpetual_v3::errors::destroy_not_empty());
        let Map {
            id                 : map_id,
            size               : _,
            counter            : _,
            root               : _,
            first              : _,
            branch_min         : _,
            branches_merge_max : _,
            branch_max         : _,
            leaf_min           : _,
            leaves_merge_max   : _,
            leaf_max           : _,
        } = map;
        sui::object::delete(map_id);
    }
    
    public(friend) fun empty<T0: copy + drop + store>(branch_min: u64, branches_merge_max: u64, branch_max: u64, leaf_min: u64, leaves_merge_max: u64, leaf_max: u64, ctx: &mut sui::tx_context::TxContext) : Map<T0> {
        check_map_params(branch_min, branches_merge_max, branch_max, leaf_min, leaves_merge_max, leaf_max);
        let counter = 0;
        let root = 9223372036854775808 | increase_counter(&mut counter);
        let map = Map<T0>{
            id                 : sui::object::new(ctx), 
            size               : 0, 
            counter            : counter, 
            root               : root, 
            first              : root, 
            branch_min         : branch_min, 
            branches_merge_max : branches_merge_max, 
            branch_max         : branch_max, 
            leaf_min           : leaf_min, 
            leaves_merge_max   : leaves_merge_max, 
            leaf_max           : leaf_max,
        };
        let first_leaf = Leaf<T0>{
            keys_vals : std::vector::empty<Pair<T0>>(), 
            next      : 0,
        };
        sui::dynamic_field::add<u64, Leaf<T0>>(&mut map.id, root, first_leaf);
        map
    }
    
    public(friend) fun insert<T0: copy + drop + store>(map: &mut Map<T0>, key: u128, val: T0) {
        let path = vector[];
        let node_id = map.root;
        while (9223372036854775808 & node_id == 0) {
            let branch = sui::dynamic_field::borrow<u64, Branch>(&map.id, node_id);
            let branch_keys = &branch.keys;
            let kid_index = binary_search(branch_keys, std::vector::length<u128>(branch_keys), key);
            std::vector::push_back<u64>(&mut path, node_id);
            std::vector::push_back<u64>(&mut path, kid_index);
            node_id = *std::vector::borrow<u64>(&branch.kids, kid_index);
        };
        let counter = map.counter;
        let leaf = sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut map.id, node_id);
        let new_leaf_size = insert_into_leaf<T0>(leaf, key, val);
        map.size = map.size + 1;
        if (new_leaf_size > map.leaf_max) {
            let (new_leaf_id, split_key, new_leaf) = split_leaf<T0>(leaf, &mut counter, new_leaf_size);
            let split_key_copy = split_key;
            let new_leaf_id_copy = new_leaf_id;
            sui::dynamic_field::add<u64, Leaf<T0>>(&mut map.id, new_leaf_id, new_leaf);
            let path_len = std::vector::length<u64>(&path);
            while (new_leaf_id_copy != 0) {
                if (path_len > 0) {
                    path_len = path_len - 2;
                    let kid_index = std::vector::pop_back<u64>(&mut path);
                    let branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, std::vector::pop_back<u64>(&mut path));
                    std::vector::insert<u128>(&mut branch.keys, split_key_copy, kid_index);
                    std::vector::insert<u64>(&mut branch.kids, new_leaf_id_copy, kid_index + 1);
                    let branch_size = std::vector::length<u64>(&branch.kids);
                    if (branch_size > map.branch_max) {
                        let (new_branch_id, new_split_key, new_branch) = split_branch(branch, &mut counter, branch_size);
                        split_key_copy = new_split_key;
                        new_leaf_id_copy = new_branch_id;
                        sui::dynamic_field::add<u64, Branch>(&mut map.id, new_branch_id, new_branch);
                        continue
                    } else {
                        break
                    };
                };
                let new_branch_keys = std::vector::empty<u128>();
                std::vector::push_back<u128>(&mut new_branch_keys, split_key_copy);
                let new_branch_kids = std::vector::empty<u64>();
                let new_branch_kids_ref = &mut new_branch_kids;
                std::vector::push_back<u64>(new_branch_kids_ref, map.root);
                std::vector::push_back<u64>(new_branch_kids_ref, new_leaf_id_copy);
                let new_branch = Branch{
                    keys : new_branch_keys, 
                    kids : new_branch_kids,
                };
                map.root = increase_counter(&mut counter);
                sui::dynamic_field::add<u64, Branch>(&mut map.id, map.root, new_branch);
                new_leaf_id_copy = 0;
            };
            map.counter = counter;
        };
    }
    
    public(friend) fun remove<T0: copy + drop + store>(map: &mut Map<T0>, key: u128) : T0 {
        let node_id = map.root;
        if (9223372036854775808 & node_id == 0) {
            let (removed_val, is_empty) = remove_from_branch<T0>(map, node_id, key);
            if (is_empty == 1) {
                let branch = sui::dynamic_field::remove<u64, Branch>(&mut map.id, node_id);
                map.root = std::vector::pop_back<u64>(&mut branch.kids);
            };
            return removed_val
        };
        let (removed_val, _) = remove_from_leaf<T0>(map, node_id, key);
        removed_val
    }
    
    fun append_left<T0: copy + drop + store>(left_vec: vector<T0>, right_vec: &mut vector<T0>) {
        reverse<T0>(right_vec);
        append_reversed_right<T0>(right_vec, left_vec);
        reverse<T0>(right_vec);
    }
    
    fun append_reversed_right<T0: copy + drop + store>(left_vec: &mut vector<T0>, right_vec: vector<T0>) {
        while (std::vector::length<T0>(&right_vec) > 0) {
            std::vector::push_back<T0>(left_vec, std::vector::pop_back<T0>(&mut right_vec));
        };
        std::vector::destroy_empty<T0>(right_vec);
    }
    
    fun append_right<T0: copy + drop + store>(left_vec: &mut vector<T0>, right_vec: &vector<T0>) {
        let i = 0;
        while (i < std::vector::length<T0>(right_vec)) {
            std::vector::push_back<T0>(left_vec, *std::vector::borrow<T0>(right_vec, i));
            i = i + 1;
        };
    }
    
    public(friend) fun batch_drop<T0: copy + drop + store>(map: &mut Map<T0>, key: u128, inclusive: bool) {
        if (!inclusive) {
            if (key == 0) {
                return
            };
            key = key - 1;
        };
        batch_drop_from_root<T0>(map, key);
        return
    }
    
    fun batch_drop_from_branch<T0: copy + drop + store>(map: &mut Map<T0>, branch_id: u64, split_key: u128, first_kid: u64, key: u128) : u128 {
        let branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, branch_id);
        let branch_keys = &branch.keys;
        let branch_size = std::vector::length<u128>(branch_keys);
        let kid_index = binary_search(branch_keys, branch_size, key);
        let kid_index_inclusive = if (kid_index < branch_size && *std::vector::borrow<u128>(branch_keys, kid_index) == key) {
            kid_index + 1
        } else {
            kid_index
        };
        let branch_kids = &mut branch.kids;
        let kid_id = *std::vector::borrow_mut<u64>(branch_kids, kid_index);
        let is_branch = 9223372036854775808 & kid_id == 0;
        drop_left<u128>(&mut branch.keys, kid_index_inclusive);
        let dropped_kids = if (is_branch) {
            cut_reversed_left<u64>(branch_kids, kid_index_inclusive)
        } else {
            drop_left<u64>(branch_kids, kid_index_inclusive);
            vector[]
        };
        let remaining_size = branch_size - kid_index_inclusive + 1;
        if (remaining_size == 0) {
            if (remaining_size < map.branch_min) {
                split_key = migrate_to_left_branch<T0>(map, branch_id, remaining_size, split_key, first_kid);
            };
            drop_kids<T0>(map, kid_index_inclusive, is_branch, dropped_kids);
            return split_key
        };
        let (new_first_kid, new_split_key) = if (remaining_size <= map.branch_min) {
            let (migrated_split_key, migrated_first_kid, x) = migrate_to_left_branch1<T0>(map, branch_id, remaining_size, split_key, first_kid);
            split_key = migrated_split_key;
            (x, migrated_first_kid)
        } else {
            (*std::vector::borrow_mut<u64>(branch_kids, 1), *std::vector::borrow_mut<u128>(&mut branch.keys, 0))
        };
        drop_kids<T0>(map, kid_index_inclusive, is_branch, dropped_kids);
        if (is_branch) {
            let new_split_key_from_branch = batch_drop_from_branch<T0>(map, kid_id, new_split_key, new_first_kid, key);
            if (new_split_key_from_branch != new_split_key) {
                let branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, branch_id);
                if (new_split_key_from_branch == 0) {
                    drop_first<u128>(&mut branch.keys);
                    drop_second<u64>(&mut branch.kids);
                    return split_key
                };
                *std::vector::borrow_mut<u128>(&mut branch.keys, 0) = new_split_key_from_branch;
                return split_key
            };
            return split_key
        };
        let remaining_leaf_size = batch_drop_from_leaf<T0>(map, kid_id, key);
        if (remaining_leaf_size < map.leaf_min) {
            let new_split_key_from_leaf = migrate_to_left_leaf<T0>(map, kid_id, remaining_leaf_size, new_first_kid);
            let branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, branch_id);
            if (new_split_key_from_leaf == 0) {
                drop_first<u128>(&mut branch.keys);
                drop_second<u64>(&mut branch.kids);
                return split_key
            };
            *std::vector::borrow_mut<u128>(&mut branch.keys, 0) = new_split_key_from_leaf;
            return split_key
        };
        split_key
    }
    
    fun batch_drop_from_leaf<T: copy + drop + store>(map: &mut Map<T>, leaf_id: u64, key: u128) : u64 {
        let leaf = sui::dynamic_field::borrow_mut<u64, Leaf<T>>(&mut map.id, leaf_id);
        let leaf_keys_vals = &leaf.keys_vals;
        let leaf_size = std::vector::length<Pair<T>>(leaf_keys_vals);
        let drop_index = binary_search_rightmost<T>(leaf_keys_vals, leaf_size, key);
        drop_left<Pair<T>>(&mut leaf.keys_vals, drop_index);
        map.size = map.size - drop_index;
        leaf_size - drop_index
    }

    fun batch_drop_from_root<T: copy + drop + store>(map: &mut Map<T>, key: u128) {
        let node_id = map.root;
        loop {
            if (9223372036854775808 & node_id != 0) {
                batch_drop_from_leaf<T>(map, node_id, key);
                return
            };
            let branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, node_id);
            let branch_keys = &branch.keys;
            let branch_size = std::vector::length<u128>(branch_keys);
            let kid_index = binary_search(branch_keys, branch_size, key);
            let kid_index_inclusive = if (kid_index < branch_size && *std::vector::borrow<u128>(branch_keys, kid_index) == key) {
                kid_index + 1
            } else {
                kid_index
            };
            let branch_kids = &mut branch.kids;
            let kid_id = *std::vector::borrow_mut<u64>(branch_kids, kid_index);
            let is_branch = 9223372036854775808 & kid_id == 0;
            drop_left<u128>(&mut branch.keys, kid_index_inclusive);
            let dropped_kids = if (is_branch) {
                cut_reversed_left<u64>(branch_kids, kid_index_inclusive)
            } else {
                drop_left<u64>(branch_kids, kid_index_inclusive);
                vector[]
            };
            let remaining_size = branch_size - kid_index_inclusive;
            if (remaining_size == 0) {
                drop_kids<T>(map, kid_index_inclusive, is_branch, dropped_kids);
                let removed_branch = sui::dynamic_field::remove<u64, Branch>(&mut map.id, node_id);
                let new_root = std::vector::pop_back<u64>(&mut removed_branch.kids);
                node_id = new_root;
                map.root = new_root;
                if (node_id & 9223372036854775808 != 0) {
                    break
                };
                continue
            };
            if (node_id & 9223372036854775808 != 0) {
                drop_kids<T>(map, kid_index_inclusive, is_branch, dropped_kids);
                return
            };
            let new_split_key = *std::vector::borrow_mut<u128>(&mut branch.keys, 0);
            drop_kids<T>(map, kid_index_inclusive, is_branch, dropped_kids);
            if (is_branch) {
                let new_split_key_from_branch = batch_drop_from_branch<T>(map, kid_id, new_split_key, *std::vector::borrow_mut<u64>(branch_kids, 1), key);
                if (new_split_key_from_branch != new_split_key) {
                    let branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, node_id);
                    if (new_split_key_from_branch == 0) {
                        drop_first<u128>(&mut branch.keys);
                        drop_second<u64>(&mut branch.kids);
                        if (remaining_size == 1) {
                            let removed_branch = sui::dynamic_field::remove<u64, Branch>(&mut map.id, node_id);
                            map.root = std::vector::pop_back<u64>(&mut removed_branch.kids);
                            return
                        };
                        return
                    };
                    *std::vector::borrow_mut<u128>(&mut branch.keys, 0) = new_split_key_from_branch;
                    return
                };
                return
            };
            let remaining_leaf_size = batch_drop_from_leaf<T>(map, kid_id, key);
            if (remaining_leaf_size < map.leaf_min) {
                let new_split_key_from_leaf = migrate_to_left_leaf<T>(map, kid_id, remaining_leaf_size, *std::vector::borrow_mut<u64>(branch_kids, 1));
                let branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, node_id);
                if (new_split_key_from_leaf == 0) {
                    drop_first<u128>(&mut branch.keys);
                    drop_second<u64>(&mut branch.kids);
                    if (remaining_size == 1) {
                        let removed_branch = sui::dynamic_field::remove<u64, Branch>(&mut map.id, node_id);
                        map.root = std::vector::pop_back<u64>(&mut removed_branch.kids);
                        return
                    };
                    return
                };
                *std::vector::borrow_mut<u128>(&mut branch.keys, 0) = new_split_key_from_leaf;
                return
            };
            return
        };
    }
    fun binary_search(keys: &vector<u128>, size: u64, target: u128) : u64 {
        let low = 0;
        while (low < size) {
            let mid = low + size >> 1;
            if (*std::vector::borrow<u128>(keys, mid) < target) {
                low = mid + 1;
                continue
            };
            size = mid;
        };
        low
    }

    fun binary_search_p<T: copy + drop + store>(pairs: &vector<Pair<T>>, size: u64, target_key: u128) : u64 {
        let low = 0;
        while (low < size) {
            let mid = low + size >> 1;
            if (std::vector::borrow<Pair<T>>(pairs, mid).key < target_key) {
                low = mid + 1;
                continue
            };
            size = mid;
        };
        low
    }

    fun binary_search_rightmost<T: copy + drop + store>(pairs: &vector<Pair<T>>, size: u64, target_key: u128) : u64 {
        let low = 0;
        while (low < size) {
            let mid = low + size >> 1;
            if (std::vector::borrow<Pair<T>>(pairs, mid).key > target_key) {
                size = mid;
                continue
            };
            low = mid + 1;
        };
        size
    }

    public(friend) fun change_params<T: copy + drop + store>(map: &mut Map<T>, new_branch_min: u64, new_branches_merge_max: u64, new_branch_max: u64, new_leaf_min: u64, new_leaves_merge_max: u64, new_leaf_max: u64) {
        check_map_params(new_branch_min, new_branches_merge_max, new_branch_max, new_leaf_min, new_leaves_merge_max, new_leaf_max);
        assert!(map.size > 3, perpetual_v3::errors::map_too_small());
        assert!(new_branch_min <= map.branch_min && map.branch_max <= new_branch_max, perpetual_v3::errors::invalid_map_parameters());
        assert!(new_leaf_min <= map.leaf_min && map.leaf_max <= new_leaf_max, perpetual_v3::errors::invalid_map_parameters());
        map.branch_min = new_branch_min;
        map.branches_merge_max = new_branches_merge_max;
        map.branch_max = new_branch_max;
        map.leaf_min = new_leaf_min;
        map.leaves_merge_max = new_leaves_merge_max;
        map.leaf_max = new_leaf_max;
    }

    fun check_map_params(branch_min: u64, branches_merge_max: u64, branch_max: u64, leaf_min: u64, leaves_merge_max: u64, leaf_max: u64) {
        assert!(2 <= branch_min && branch_min <= branch_max / 2, perpetual_v3::errors::invalid_map_parameters());
        assert!(2 * branch_min <= branches_merge_max && branches_merge_max <= branch_max, perpetual_v3::errors::invalid_map_parameters());
        assert!(2 <= leaf_min && leaf_min <= (leaf_max + 1) / 2, perpetual_v3::errors::invalid_map_parameters());
        assert!(2 * leaf_min - 1 <= leaves_merge_max && leaves_merge_max <= leaf_max, perpetual_v3::errors::invalid_map_parameters());
    }

    public(friend) fun clear<T: copy + drop + store>(map: &mut Map<T>) {
        let root_id = map.root;
        let node_id = root_id;
        if (9223372036854775808 & root_id == 0) {
            let removed_branch = sui::dynamic_field::remove<u64, Branch>(&mut map.id, node_id);
            let branch_kids = &removed_branch.kids;
            let last_kid_index = std::vector::length<u64>(branch_kids) - 1;
            let last_kid_id = *std::vector::borrow<u64>(branch_kids, last_kid_index);
            node_id = last_kid_id;
            while (9223372036854775808 & last_kid_id == 0) {
                let i = 0;
                loop {
                    if (i < last_kid_index) {
                        drop_branch<T>(map, *std::vector::borrow<u64>(branch_kids, i));
                        i = i + 1;
                        continue
                    };
                };
            };
            drop_first_leaves<T>(map, last_kid_index);
            map.root = last_kid_id;
        };
        clear_leaf<T>(map, node_id);
    }

    fun clear_leaf<T: copy + drop + store>(map: &mut Map<T>, leaf_id: u64) {
        let leaf = sui::dynamic_field::borrow_mut<u64, Leaf<T>>(&mut map.id, leaf_id);
        leaf.keys_vals = std::vector::empty<Pair<T>>();
        map.size = map.size - std::vector::length<Pair<T>>(&leaf.keys_vals);
    }

    fun copy_slice<T: copy + drop + store>(vec: &vector<T>, start: u64, end: u64) : vector<T> {
        let result = std::vector::empty<T>();
        while (start < end) {
            std::vector::push_back<T>(&mut result, *std::vector::borrow<T>(vec, start));
            start = start + 1;
        };
        result
    }

    fun cut_reversed_left<T: copy + drop + store>(vec: &mut vector<T>, cut_index: u64) : vector<T> {
        let result = std::vector::empty<T>();
        let index = cut_index;
        while (index > 0) {
            let prev_index = index - 1;
            index = prev_index;
            std::vector::push_back<T>(&mut result, *std::vector::borrow_mut<T>(vec, prev_index));
        };
        drop_left<T>(vec, cut_index);
        result
    }

    fun cut_reversed_left1<T: copy + drop + store>(vec: &mut vector<T>, cut_index: u64) : (T, vector<T>) {
        let result = std::vector::empty<T>();
        let last_index = cut_index - 1;
        let index = last_index;
        while (index > 0) {
            let prev_index = index - 1;
            index = prev_index;
            std::vector::push_back<T>(&mut result, *std::vector::borrow_mut<T>(vec, prev_index));
        };
        drop_left<T>(vec, cut_index);
        (*std::vector::borrow_mut<T>(vec, last_index), result)
    }

    fun cut_reversed_right<T: copy + drop + store>(vec: &mut vector<T>, count: u64) : vector<T> {
        let result = std::vector::empty<T>();
        while (count > 0) {
            std::vector::push_back<T>(&mut result, std::vector::pop_back<T>(vec));
            count = count - 1;
        };
        result
    }

    fun cut_right<T: copy + drop + store>(vec: &mut vector<T>, count: u64) : vector<T> {
        let result = cut_reversed_right<T>(vec, count);
        reverse<T>(&mut result);
        result
    }

    fun drop_branch<T: copy + drop + store>(map: &mut Map<T>, branch_id: u64) {
        let removed_branch = sui::dynamic_field::remove<u64, Branch>(&mut map.id, branch_id);
        let branch_kids = &removed_branch.kids;
        let first_kid_id = *std::vector::borrow<u64>(branch_kids, 0);
        if (9223372036854775808 & first_kid_id == 0) {
            drop_branch<T>(map, first_kid_id);
            let i = 1;
            while (i < std::vector::length<u64>(branch_kids)) {
                drop_branch<T>(map, *std::vector::borrow<u64>(branch_kids, i));
                i = i + 1;
            };
            return
        };
        drop_first_leaves<T>(map, std::vector::length<u64>(branch_kids));
    }

    fun drop_first<T: copy + drop + store>(vec: &mut vector<T>) {
        let len = std::vector::length<T>(vec);
        while (len > 1) {
            let last_index = len - 1;
            len = last_index;
            std::vector::swap<T>(vec, 0, last_index);
        };
        std::vector::pop_back<T>(vec);
    }

    fun drop_first_leaves<T: copy + drop + store>(map: &mut Map<T>, count: u64) {
        let dropped_count = 0;
        let leaf_id = map.first;
        while (count > 0) {
            let removed_leaf = sui::dynamic_field::remove<u64, Leaf<T>>(&mut map.id, leaf_id);
            dropped_count = dropped_count + std::vector::length<Pair<T>>(&removed_leaf.keys_vals);
            leaf_id = removed_leaf.next;
            count = count - 1;
        };
        map.size = map.size - dropped_count;
        map.first = leaf_id;
    }

    fun drop_kids<T: copy + drop + store>(map: &mut Map<T>, count: u64, is_branch: bool, dropped_kids: vector<u64>) {
        if (count == 0) {
            return
        };
        if (is_branch) {
            while (count > 0) {
                count = count - 1;
                drop_branch<T>(map, std::vector::pop_back<u64>(&mut dropped_kids));
            };
        } else {
            drop_first_leaves<T>(map, count);
        };
    }

    fun drop_left<T: copy + drop + store>(vec: &mut vector<T>, count: u64) {
        let len = std::vector::length<T>(vec);
        if (2 * count > len) {
            *vec = copy_slice<T>(vec, count, len);
            return
        };
        let index = count;
        while (index < len) {
            std::vector::swap<T>(vec, index - count, index);
            index = index + 1;
        };
        drop_right<T>(vec, count);
    }

    fun drop_right<T: copy + drop + store>(vec: &mut vector<T>, count: u64) {
        while (count > 0) {
            std::vector::pop_back<T>(vec);
            count = count - 1;
        };
    }

    fun drop_second<T: copy + drop + store>(vec: &mut vector<T>) {
        let len = std::vector::length<T>(vec);
        while (len != 2) {
            let last_index = len - 1;
            len = last_index;
            std::vector::swap<T>(vec, 1, last_index);
        };
        std::vector::pop_back<T>(vec);
    }

    public(friend) fun find_leaf<T: copy + drop + store>(map: &Map<T>, key: u128) : u64 {
        let node_id = map.root;
        while (9223372036854775808 & node_id == 0) {
            let branch = sui::dynamic_field::borrow<u64, Branch>(&map.id, node_id);
            let branch_keys = &branch.keys;
            node_id = *std::vector::borrow<u64>(&branch.kids, binary_search(branch_keys, std::vector::length<u128>(branch_keys), key));
        };
        node_id
    }

    public(friend) fun first_leaf_ptr<T: copy + drop + store>(map: &Map<T>) : u64 {
        map.first
    }

    public(friend) fun get_leaf<T: copy + drop + store>(map: &Map<T>, leaf_id: u64) : &Leaf<T> {
        sui::dynamic_field::borrow<u64, Leaf<T>>(&map.id, leaf_id)
    }

    public(friend) fun get_leaf_mut<T: copy + drop + store>(map: &mut Map<T>, leaf_id: u64) : &mut Leaf<T> {
        sui::dynamic_field::borrow_mut<u64, Leaf<T>>(&mut map.id, leaf_id)
    }

    public(friend) fun has_key<T: copy + drop + store>(map: &Map<T>, key: u128) : bool {
        let leaf_keys_vals = &sui::dynamic_field::borrow<u64, Leaf<T>>(&map.id, find_leaf<T>(map, key)).keys_vals;
        let leaf_size = std::vector::length<Pair<T>>(leaf_keys_vals);
        let pair_index = binary_search_p<T>(leaf_keys_vals, leaf_size, key);
        pair_index < leaf_size && key == std::vector::borrow<Pair<T>>(leaf_keys_vals, pair_index).key
    }

    fun increase_counter(counter: &mut u64) : u64 {
        *counter = *counter + 1;
        *counter
    }
    
    fun insert_into_leaf<T: copy + drop + store>(leaf: &mut Leaf<T>, key: u128, value: T) : u64 {
        let leaf_keys_vals = &leaf.keys_vals;
        let leaf_size = std::vector::length<Pair<T>>(leaf_keys_vals);
        let insert_index = binary_search_p<T>(leaf_keys_vals, leaf_size, key);
        assert!(insert_index == leaf_size || key != std::vector::borrow<Pair<T>>(leaf_keys_vals, insert_index).key, perpetual_v3::errors::key_already_exists());
        let new_pair = Pair<T>{
            key : key, 
            val : value,
        };
        std::vector::insert<Pair<T>>(&mut leaf.keys_vals, new_pair, insert_index);
        leaf_size + 1
    }

    public(friend) fun is_empty<T: copy + drop + store>(map: &Map<T>) : bool {
        map.size == 0
    }

    fun last<T: copy + drop + store>(vec: &vector<T>) : &T {
        std::vector::borrow<T>(vec, std::vector::length<T>(vec) - 1)
    }

    public(friend) fun leaf_elem<T: copy + drop + store>(leaf: &Leaf<T>, index: u64) : (u128, &T) {
        let pair = std::vector::borrow<Pair<T>>(&leaf.keys_vals, index);
        (pair.key, &pair.val)
    }

    public(friend) fun leaf_elem_mut<T: copy + drop + store>(leaf: &mut Leaf<T>, index: u64) : (u128, &mut T) {
        let pair = std::vector::borrow_mut<Pair<T>>(&mut leaf.keys_vals, index);
        (pair.key, &mut pair.val)
    }

    public(friend) fun leaf_find_index<T: copy + drop + store>(leaf: &Leaf<T>, key: u128) : u64 {
        let leaf_keys_vals = &leaf.keys_vals;
        binary_search_p<T>(leaf_keys_vals, std::vector::length<Pair<T>>(leaf_keys_vals), key)
    }

    public(friend) fun leaf_next<T: copy + drop + store>(leaf: &Leaf<T>) : u64 {
        leaf.next
    }

    public(friend) fun leaf_size<T: copy + drop + store>(leaf: &Leaf<T>) : u64 {
        std::vector::length<Pair<T>>(&leaf.keys_vals)
    }

    fun merge_branches<T: copy + drop + store>(map: &mut Map<T>, left_branch_id: u64, split_key: u128, right_branch_id: u64) {
        let Branch {
            keys : right_keys,
            kids : right_kids,
        } = sui::dynamic_field::remove<u64, Branch>(&mut map.id, right_branch_id);
        let right_kids_copy = right_kids;
        let right_keys_copy = right_keys;
        let left_branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, left_branch_id);
        std::vector::push_back<u128>(&mut left_branch.keys, split_key);
        append_right<u128>(&mut left_branch.keys, &right_keys_copy);
        append_right<u64>(&mut left_branch.kids, &right_kids_copy);
    }

    fun merge_leaves<T: copy + drop + store>(map: &mut Map<T>, left_leaf_id: u64, right_leaf_id: u64) {
        let Leaf {
            keys_vals : right_keys_vals,
            next      : right_next,
        } = sui::dynamic_field::remove<u64, Leaf<T>>(&mut map.id, right_leaf_id);
        let right_keys_vals_copy = right_keys_vals;
        let left_leaf = sui::dynamic_field::borrow_mut<u64, Leaf<T>>(&mut map.id, left_leaf_id);
        append_right<Pair<T>>(&mut left_leaf.keys_vals, &right_keys_vals_copy);
        left_leaf.next = right_next;
    }

    fun migrate_to_left_branch<T: copy + drop + store>(map: &mut Map<T>, left_branch_id: u64, left_size: u64, split_key: u128, right_branch_id: u64) : u128 {
        let right_branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, right_branch_id);
        let merged_size = left_size + std::vector::length<u64>(&right_branch.kids);
        if (merged_size <= map.branches_merge_max) {
            merge_branches<T>(map, left_branch_id, split_key, right_branch_id);
            return 0
        };
        let migrate_count = (merged_size + 1) / 2 - left_size;
        let (new_split_key, migrated_keys) = cut_reversed_left1<u128>(&mut right_branch.keys, migrate_count);
        let left_branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, left_branch_id);
        std::vector::push_back<u128>(&mut left_branch.keys, split_key);
        append_reversed_right<u128>(&mut left_branch.keys, migrated_keys);
        append_reversed_right<u64>(&mut left_branch.kids, cut_reversed_left<u64>(&mut right_branch.kids, migrate_count));
        new_split_key
    }

    fun migrate_to_left_branch1<T: copy + drop + store>(map: &mut Map<T>, left_branch_id: u64, left_size: u64, split_key: u128, right_branch_id: u64) : (u128, u128, u64) {
        let right_branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, right_branch_id);
        let merged_size = left_size + std::vector::length<u64>(&right_branch.kids);
        if (merged_size <= map.branches_merge_max) {
            let Branch {
                keys : right_keys,
                kids : right_kids,
            } = sui::dynamic_field::remove<u64, Branch>(&mut map.id, right_branch_id);
            let right_kids_copy = right_kids;
            let right_keys_copy = right_keys;
            let left_branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, left_branch_id);
            let left_keys = &mut left_branch.keys;
            let left_kids = &mut left_branch.kids;
            std::vector::push_back<u128>(left_keys, split_key);
            append_right<u128>(left_keys, &right_keys_copy);
            append_right<u64>(left_kids, &right_kids_copy);
            return (0, *std::vector::borrow_mut<u128>(left_keys, 0), *std::vector::borrow_mut<u64>(left_kids, 1))
        };
        let migrate_count = (merged_size + 1) / 2 - left_size;
        let (new_split_key, migrated_keys) = cut_reversed_left1<u128>(&mut right_branch.keys, migrate_count);
        let left_branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, left_branch_id);
        let left_keys = &mut left_branch.keys;
        let left_kids = &mut left_branch.kids;
        std::vector::push_back<u128>(left_keys, split_key);
        append_reversed_right<u128>(left_keys, migrated_keys);
        append_reversed_right<u64>(left_kids, cut_reversed_left<u64>(&mut right_branch.kids, migrate_count));
        (new_split_key, *std::vector::borrow_mut<u128>(left_keys, 0), *std::vector::borrow_mut<u64>(left_kids, 1))
    }

    fun migrate_to_left_leaf<T: copy + drop + store>(map: &mut Map<T>, left_leaf_id: u64, left_size: u64, right_leaf_id: u64) : u128 {
        let right_leaf = sui::dynamic_field::borrow_mut<u64, Leaf<T>>(&mut map.id, right_leaf_id);
        let merged_size = left_size + std::vector::length<Pair<T>>(&right_leaf.keys_vals);
        if (merged_size <= map.leaves_merge_max) {
            merge_leaves<T>(map, left_leaf_id, right_leaf_id);
            return 0
        };
        let left_leaf = sui::dynamic_field::borrow_mut<u64, Leaf<T>>(&mut map.id, left_leaf_id);
        append_reversed_right<Pair<T>>(&mut left_leaf.keys_vals, cut_reversed_left<Pair<T>>(&mut right_leaf.keys_vals, merged_size / 2 - left_size));
        last<Pair<T>>(&left_leaf.keys_vals).key
    }

    fun migrate_to_right_branch<T: copy + drop + store>(map: &mut Map<T>, left_branch_id: u64, split_key: u128, right_branch_id: u64, right_size: u64) : u128 {
        let left_branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, left_branch_id);
        let merged_size = std::vector::length<u64>(&left_branch.kids) + right_size;
        if (merged_size <= map.branches_merge_max) {
            merge_branches<T>(map, left_branch_id, split_key, right_branch_id);
            return 0
        };
        let migrate_count = merged_size / 2 - right_size;
        let migrated_keys = cut_right<u128>(&mut left_branch.keys, migrate_count - 1);
        let right_branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, right_branch_id);
        std::vector::push_back<u128>(&mut migrated_keys, split_key);
        append_left<u128>(migrated_keys, &mut right_branch.keys);
        append_left<u64>(cut_right<u64>(&mut left_branch.kids, migrate_count), &mut right_branch.kids);
        std::vector::pop_back<u128>(&mut left_branch.keys)
    }

    fun migrate_to_right_leaf<T: copy + drop + store>(map: &mut Map<T>, left_leaf_id: u64, right_leaf_id: u64, right_size: u64) : u128 {
        let left_leaf = sui::dynamic_field::borrow_mut<u64, Leaf<T>>(&mut map.id, left_leaf_id);
        let merged_size = std::vector::length<Pair<T>>(&left_leaf.keys_vals) + right_size;
        if (merged_size <= map.leaves_merge_max) {
            merge_leaves<T>(map, left_leaf_id, right_leaf_id);
            return 0
        };
        append_left<Pair<T>>(cut_right<Pair<T>>(&mut left_leaf.keys_vals, merged_size / 2 - right_size), &mut sui::dynamic_field::borrow_mut<u64, Leaf<T>>(&mut map.id, right_leaf_id).keys_vals);
        last<Pair<T>>(&left_leaf.keys_vals).key
    }

    public(friend) fun min_key<T: copy + drop + store>(map: &Map<T>) : u128 {
        std::vector::borrow<Pair<T>>(&sui::dynamic_field::borrow<u64, Leaf<T>>(&map.id, map.first).keys_vals, 0).key
    }

    fun remove_at<T: copy + drop + store>(vec: &mut vector<T>, index: u64) : T {
        let last_index = std::vector::length<T>(vec) - 1;
        while (last_index != index) {
            std::vector::swap<T>(vec, index, last_index);
            last_index = last_index - 1;
        };
        std::vector::pop_back<T>(vec)
    }
    fun remove_from_branch<T: copy + drop + store>(map: &mut Map<T>, branch_id: u64, key: u128) : (T, u64) {
        let branch = sui::dynamic_field::borrow<u64, Branch>(&map.id, branch_id);
        let branch_keys = &branch.keys;
        let branch_size = std::vector::length<u128>(branch_keys);
        let kid_index = binary_search(branch_keys, branch_size, key);
        let branch_kids = &branch.kids;
        let kid_id = *std::vector::borrow<u64>(branch_kids, kid_index);
        if (9223372036854775808 & kid_id == 0) {
            if (kid_index < branch_size) {
                let next_kid_index = kid_index + 1;
                let (removed_val, remaining_size) = remove_from_branch<T>(map, kid_id, key);
                if (remaining_size < map.branch_min) {
                    update_after_migration<T>(map, branch_id, &mut branch_size, kid_index, migrate_to_left_branch<T>(map, kid_id, remaining_size, *std::vector::borrow<u128>(branch_keys, kid_index), *std::vector::borrow<u64>(branch_kids, next_kid_index)), next_kid_index);
                };
                return (removed_val, branch_size + 1)
            };
            let prev_kid_index = kid_index - 1;
            let (removed_val, remaining_size) = remove_from_branch<T>(map, kid_id, key);
            if (remaining_size < map.branch_min) {
                update_after_migration_last<T>(map, branch_id, &mut branch_size, prev_kid_index, migrate_to_right_branch<T>(map, *std::vector::borrow<u64>(branch_kids, prev_kid_index), *std::vector::borrow<u128>(branch_keys, prev_kid_index), kid_id, remaining_size));
            };
            return (removed_val, branch_size + 1)
        };
        if (kid_index < branch_size) {
            let next_kid_index = kid_index + 1;
            let (removed_val, remaining_size) = remove_from_leaf<T>(map, kid_id, key);
            if (remaining_size < map.leaf_min) {
                update_after_migration<T>(map, branch_id, &mut branch_size, kid_index, migrate_to_left_leaf<T>(map, kid_id, remaining_size, *std::vector::borrow<u64>(branch_kids, next_kid_index)), next_kid_index);
            };
            return (removed_val, branch_size + 1)
        };
        let prev_kid_index = kid_index - 1;
        let (removed_val, remaining_size) = remove_from_leaf<T>(map, kid_id, key);
        if (remaining_size < map.leaf_min) {
            update_after_migration_last<T>(map, branch_id, &mut branch_size, prev_kid_index, migrate_to_right_leaf<T>(map, *std::vector::borrow<u64>(branch_kids, prev_kid_index), kid_id, remaining_size));
        };
        (removed_val, branch_size + 1)
    }

    fun remove_from_leaf<T: copy + drop + store>(map: &mut Map<T>, leaf_id: u64, key: u128) : (T, u64) {
        let leaf = sui::dynamic_field::borrow_mut<u64, Leaf<T>>(&mut map.id, leaf_id);
        let leaf_keys_vals = &leaf.keys_vals;
        let leaf_size = std::vector::length<Pair<T>>(leaf_keys_vals);
        let removed_pair = remove_at<Pair<T>>(&mut leaf.keys_vals, binary_search_p<T>(leaf_keys_vals, leaf_size, key));
        assert!(key == removed_pair.key, perpetual_v3::errors::key_not_exist());
        map.size = map.size - 1;
        (removed_pair.val, leaf_size - 1)
    }

    fun reverse<T: copy + drop + store>(vec: &mut vector<T>) {
        let len = std::vector::length<T>(vec);
        if (len <= 1) {
            return
        };
        let mid = len / 2;
        while (mid > 0) {
            let prev_mid = mid - 1;
            mid = prev_mid;
            std::vector::swap<T>(vec, prev_mid, len - 1 - prev_mid);
        };
    }

    public(friend) fun size<T: copy + drop + store>(map: &Map<T>) : u64 {
        map.size
    }

    fun split_branch(branch: &mut Branch, counter: &mut u64, branch_size: u64) : (u64, u128, Branch) {
        let mid = branch_size >> 1;
        let new_branch = Branch{
            keys : cut_right<u128>(&mut branch.keys, mid - 1), 
            kids : cut_right<u64>(&mut branch.kids, mid),
        };
        (increase_counter(counter), std::vector::pop_back<u128>(&mut branch.keys), new_branch)
    }

    fun split_leaf<T: copy + drop + store>(leaf: &mut Leaf<T>, counter: &mut u64, leaf_size: u64) : (u64, u128, Leaf<T>) {
        let mid = leaf_size >> 1;
        let new_leaf_id = 9223372036854775808 | increase_counter(counter);
        leaf.next = new_leaf_id;
        let new_leaf = Leaf<T>{
            keys_vals : cut_right<Pair<T>>(&mut leaf.keys_vals, mid), 
            next      : leaf.next,
        };
        (new_leaf_id, std::vector::borrow<Pair<T>>(&leaf.keys_vals, leaf_size - mid - 1).key, new_leaf)
    }

    fun update_after_migration<T: copy + drop + store>(map: &mut Map<T>, branch_id: u64, branch_size: &mut u64, kid_index: u64, new_split_key: u128, next_kid_index: u64) {
        let branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, branch_id);
        if (new_split_key == 0) {
            remove_at<u128>(&mut branch.keys, kid_index);
            remove_at<u64>(&mut branch.kids, next_kid_index);
            *branch_size = *branch_size - 1;
            return
        };
        *std::vector::borrow_mut<u128>(&mut branch.keys, kid_index) = new_split_key;
    }

    fun update_after_migration_last<T: copy + drop + store>(map: &mut Map<T>, branch_id: u64, branch_size: &mut u64, prev_kid_index: u64, new_split_key: u128) {
        let branch = sui::dynamic_field::borrow_mut<u64, Branch>(&mut map.id, branch_id);
        if (new_split_key == 0) {
            std::vector::pop_back<u128>(&mut branch.keys);
            std::vector::pop_back<u64>(&mut branch.kids);
            *branch_size = *branch_size - 1;
            return
        };
        *std::vector::borrow_mut<u128>(&mut branch.keys, prev_kid_index) = new_split_key;
    }

    // decompiled from Move bytecode v6
}

