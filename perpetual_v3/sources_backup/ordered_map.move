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
    
    public(friend) fun borrow<T0: copy + drop + store>(arg0: &Map<T0>, arg1: u128) : &T0 {
        let v0 = &sui::dynamic_field::borrow<u64, Leaf<T0>>(&arg0.id, find_leaf<T0>(arg0, arg1)).keys_vals;
        let v1 = std::vector::borrow<Pair<T0>>(v0, binary_search_p<T0>(v0, std::vector::length<Pair<T0>>(v0), arg1));
        assert!(arg1 == v1.key, perpetual_v3::errors::key_not_exist());
        &v1.val
    }
    
    public(friend) fun borrow_mut<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u128) : &mut T0 {
        let v0 = sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut arg0.id, find_leaf<T0>(arg0, arg1));
        let v1 = &v0.keys_vals;
        let v2 = std::vector::borrow_mut<Pair<T0>>(&mut v0.keys_vals, binary_search_p<T0>(v1, std::vector::length<Pair<T0>>(v1), arg1));
        assert!(arg1 == v2.key, perpetual_v3::errors::key_not_exist());
        &mut v2.val
    }
    
    public(friend) fun destroy_empty<T0: copy + drop + store>(arg0: Map<T0>) {
        assert!(is_empty<T0>(&arg0), perpetual_v3::errors::destroy_not_empty());
        let Map {
            id                 : v0,
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
        } = arg0;
        sui::object::delete(v0);
    }
    
    public(friend) fun empty<T0: copy + drop + store>(arg0: u64, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64, arg6: &mut sui::tx_context::TxContext) : Map<T0> {
        check_map_params(arg0, arg1, arg2, arg3, arg4, arg5);
        let v0 = 0;
        let v1 = 9223372036854775808 | increase_counter(&mut v0);
        let v2 = Map<T0>{
            id                 : sui::object::new(arg6), 
            size               : 0, 
            counter            : v0, 
            root               : v1, 
            first              : v1, 
            branch_min         : arg0, 
            branches_merge_max : arg1, 
            branch_max         : arg2, 
            leaf_min           : arg3, 
            leaves_merge_max   : arg4, 
            leaf_max           : arg5,
        };
        let v3 = Leaf<T0>{
            keys_vals : std::vector::empty<Pair<T0>>(), 
            next      : 0,
        };
        sui::dynamic_field::add<u64, Leaf<T0>>(&mut v2.id, v1, v3);
        v2
    }
    
    public(friend) fun insert<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u128, arg2: T0) {
        let v0 = vector[];
        let v1 = arg0.root;
        while (9223372036854775808 & v1 == 0) {
            let v2 = sui::dynamic_field::borrow<u64, Branch>(&arg0.id, v1);
            let v3 = &v2.keys;
            let v4 = binary_search(v3, std::vector::length<u128>(v3), arg1);
            std::vector::push_back<u64>(&mut v0, v1);
            std::vector::push_back<u64>(&mut v0, v4);
            v1 = *std::vector::borrow<u64>(&v2.kids, v4);
        };
        let v5 = arg0.counter;
        let v6 = sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut arg0.id, v1);
        let v7 = insert_into_leaf<T0>(v6, arg1, arg2);
        arg0.size = arg0.size + 1;
        if (v7 > arg0.leaf_max) {
            let (v8, v9, v10) = split_leaf<T0>(v6, &mut v5, v7);
            let v11 = v9;
            let v12 = v8;
            sui::dynamic_field::add<u64, Leaf<T0>>(&mut arg0.id, v8, v10);
            let v13 = std::vector::length<u64>(&v0);
            while (v12 != 0) {
                if (v13 > 0) {
                    v13 = v13 - 2;
                    let v14 = std::vector::pop_back<u64>(&mut v0);
                    let v15 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, std::vector::pop_back<u64>(&mut v0));
                    std::vector::insert<u128>(&mut v15.keys, v11, v14);
                    std::vector::insert<u64>(&mut v15.kids, v12, v14 + 1);
                    let v16 = std::vector::length<u64>(&v15.kids);
                    if (v16 > arg0.branch_max) {
                        let (v17, v18, v19) = split_branch(v15, &mut v5, v16);
                        v11 = v18;
                        v12 = v17;
                        sui::dynamic_field::add<u64, Branch>(&mut arg0.id, v17, v19);
                        continue
                    } else {
                        break
                    };
                };
                let v20 = std::vector::empty<u128>();
                std::vector::push_back<u128>(&mut v20, v11);
                let v21 = std::vector::empty<u64>();
                let v22 = &mut v21;
                std::vector::push_back<u64>(v22, arg0.root);
                std::vector::push_back<u64>(v22, v12);
                let v23 = Branch{
                    keys : v20, 
                    kids : v21,
                };
                arg0.root = increase_counter(&mut v5);
                sui::dynamic_field::add<u64, Branch>(&mut arg0.id, arg0.root, v23);
                v12 = 0;
            };
            arg0.counter = v5;
        };
    }
    
    public(friend) fun remove<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u128) : T0 {
        let v0 = arg0.root;
        if (9223372036854775808 & v0 == 0) {
            let (v1, v2) = remove_from_branch<T0>(arg0, v0, arg1);
            if (v2 == 1) {
                let v3 = sui::dynamic_field::remove<u64, Branch>(&mut arg0.id, v0);
                arg0.root = std::vector::pop_back<u64>(&mut v3.kids);
            };
            return v1
        };
        let (v4, _) = remove_from_leaf<T0>(arg0, v0, arg1);
        v4
    }
    
    fun append_left<T0: copy + drop + store>(arg0: vector<T0>, arg1: &mut vector<T0>) {
        reverse<T0>(arg1);
        append_reversed_right<T0>(arg1, arg0);
        reverse<T0>(arg1);
    }
    
    fun append_reversed_right<T0: copy + drop + store>(arg0: &mut vector<T0>, arg1: vector<T0>) {
        while (std::vector::length<T0>(&arg1) > 0) {
            std::vector::push_back<T0>(arg0, std::vector::pop_back<T0>(&mut arg1));
        };
        std::vector::destroy_empty<T0>(arg1);
    }
    
    fun append_right<T0: copy + drop + store>(arg0: &mut vector<T0>, arg1: &vector<T0>) {
        let v0 = 0;
        while (v0 < std::vector::length<T0>(arg1)) {
            std::vector::push_back<T0>(arg0, *std::vector::borrow<T0>(arg1, v0));
            v0 = v0 + 1;
        };
    }
    
    public(friend) fun batch_drop<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u128, arg2: bool) {
        if (!arg2) {
            if (arg1 == 0) {
                return
            };
            arg1 = arg1 - 1;
        };
        batch_drop_from_root<T0>(arg0, arg1);
        return
    }
    
    fun batch_drop_from_branch<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u128, arg3: u64, arg4: u128) : u128 {
        let v0 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg1);
        let v1 = &v0.keys;
        let v2 = std::vector::length<u128>(v1);
        let v3 = binary_search(v1, v2, arg4);
        let v4 = if (v3 < v2 && *std::vector::borrow<u128>(v1, v3) == arg4) {
            v3 + 1
        } else {
            v3
        };
        let v5 = &mut v0.kids;
        let v6 = *std::vector::borrow_mut<u64>(v5, v3);
        let v7 = 9223372036854775808 & v6 == 0;
        drop_left<u128>(&mut v0.keys, v4);
        let v8 = if (v7) {
            cut_reversed_left<u64>(v5, v4)
        } else {
            drop_left<u64>(v5, v4);
            vector[]
        };
        let v9 = v2 - v4 + 1;
        if (v20) {
            if (v9 < arg0.branch_min) {
                arg2 = migrate_to_left_branch<T0>(arg0, arg1, v9, arg2, arg3);
            };
            drop_kids<T0>(arg0, v4, v7, v8);
            return arg2
        };
        let (v10, v11) = if (v9 <= arg0.branch_min) {
            let (v12, v13, v14) = migrate_to_left_branch1<T0>(arg0, arg1, v9, arg2, arg3);
            arg2 = v12;
            (v14, v13)
        } else {
            (*std::vector::borrow_mut<u64>(v5, 1), *std::vector::borrow_mut<u128>(&mut v0.keys, 0))
        };
        drop_kids<T0>(arg0, v4, v7, v8);
        if (v7) {
            let v15 = batch_drop_from_branch<T0>(arg0, v6, v11, v10, arg4);
            if (v15 != v11) {
                let v16 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg1);
                if (v15 == 0) {
                    drop_first<u128>(&mut v16.keys);
                    drop_second<u64>(&mut v16.kids);
                    return arg2
                };
                *std::vector::borrow_mut<u128>(&mut v16.keys, 0) = v15;
                return arg2
            };
            return arg2
        };
        let v17 = batch_drop_from_leaf<T0>(arg0, v6, arg4);
        if (v17 < arg0.leaf_min) {
            let v18 = migrate_to_left_leaf<T0>(arg0, v6, v17, v10);
            let v19 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg1);
            if (v18 == 0) {
                drop_first<u128>(&mut v19.keys);
                drop_second<u64>(&mut v19.kids);
                return arg2
            };
            *std::vector::borrow_mut<u128>(&mut v19.keys, 0) = v18;
            return arg2
        };
        arg2
    }
    
    fun batch_drop_from_leaf<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u128) : u64 {
        let v0 = sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut arg0.id, arg1);
        let v1 = &v0.keys_vals;
        let v2 = std::vector::length<Pair<T0>>(v1);
        let v3 = binary_search_rightmost<T0>(v1, v2, arg2);
        drop_left<Pair<T0>>(&mut v0.keys_vals, v3);
        arg0.size = arg0.size - v3;
        v2 - v3
    }
    
    fun batch_drop_from_root<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u128) {
        let v0 = arg0.root;
        loop {
            if (9223372036854775808 & v0 != 0) {
                batch_drop_from_leaf<T0>(arg0, v0, arg1);
                return
            };
            let v1 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, v0);
            let v2 = &v1.keys;
            let v3 = std::vector::length<u128>(v2);
            let v4 = binary_search(v2, v3, arg1);
            let v5 = if (v4 < v3 && *std::vector::borrow<u128>(v2, v4) == arg1) {
                v4 + 1
            } else {
                v4
            };
            let v6 = &mut v1.kids;
            let v7 = *std::vector::borrow_mut<u64>(v6, v4);
            let v8 = 9223372036854775808 & v7 == 0;
            drop_left<u128>(&mut v1.keys, v5);
            let v9 = if (v8) {
                cut_reversed_left<u64>(v6, v5)
            } else {
                drop_left<u64>(v6, v5);
                vector[]
            };
            let v10 = v3 - v5;
            if (v10 == 0) {
                drop_kids<T0>(arg0, v5, v8, v9);
                let v11 = sui::dynamic_field::remove<u64, Branch>(&mut arg0.id, v0);
                let v12 = std::vector::pop_back<u64>(&mut v11.kids);
                v0 = v12;
                arg0.root = v12;
                if (v21) {
                    break
                };
                continue
            };
            if (v21) {
                drop_kids<T0>(arg0, v5, v8, v9);
                return
            };
            let v13 = *std::vector::borrow_mut<u128>(&mut v1.keys, 0);
            drop_kids<T0>(arg0, v5, v8, v9);
            if (v8) {
                let v14 = batch_drop_from_branch<T0>(arg0, v7, v13, *std::vector::borrow_mut<u64>(v6, 1), arg1);
                if (v14 != v13) {
                    let v15 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, v0);
                    if (v14 == 0) {
                        drop_first<u128>(&mut v15.keys);
                        drop_second<u64>(&mut v15.kids);
                        if (v10 == 1) {
                            let v16 = sui::dynamic_field::remove<u64, Branch>(&mut arg0.id, v0);
                            arg0.root = std::vector::pop_back<u64>(&mut v16.kids);
                            return
                        };
                        return
                    };
                    *std::vector::borrow_mut<u128>(&mut v15.keys, 0) = v14;
                    return
                };
                return
            };
            let v17 = batch_drop_from_leaf<T0>(arg0, v7, arg1);
            if (v17 < arg0.leaf_min) {
                let v18 = migrate_to_left_leaf<T0>(arg0, v7, v17, *std::vector::borrow_mut<u64>(v6, 1));
                let v19 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, v0);
                if (v18 == 0) {
                    drop_first<u128>(&mut v19.keys);
                    drop_second<u64>(&mut v19.kids);
                    if (v10 == 1) {
                        let v20 = sui::dynamic_field::remove<u64, Branch>(&mut arg0.id, v0);
                        arg0.root = std::vector::pop_back<u64>(&mut v20.kids);
                        return
                    };
                    return
                };
                *std::vector::borrow_mut<u128>(&mut v19.keys, 0) = v18;
                return
            };
            return
        };
    }
    
    fun binary_search(arg0: &vector<u128>, arg1: u64, arg2: u128) : u64 {
        let v0 = 0;
        while (v0 < arg1) {
            let v1 = v0 + arg1 >> 1;
            if (*std::vector::borrow<u128>(arg0, v1) < arg2) {
                v0 = v1 + 1;
                continue
            };
            arg1 = v1;
        };
        v0
    }
    
    fun binary_search_p<T0: copy + drop + store>(arg0: &vector<Pair<T0>>, arg1: u64, arg2: u128) : u64 {
        let v0 = 0;
        while (v0 < arg1) {
            let v1 = v0 + arg1 >> 1;
            if (std::vector::borrow<Pair<T0>>(arg0, v1).key < arg2) {
                v0 = v1 + 1;
                continue
            };
            arg1 = v1;
        };
        v0
    }
    
    fun binary_search_rightmost<T0: copy + drop + store>(arg0: &vector<Pair<T0>>, arg1: u64, arg2: u128) : u64 {
        let v0 = 0;
        while (v0 < arg1) {
            let v1 = v0 + arg1 >> 1;
            if (std::vector::borrow<Pair<T0>>(arg0, v1).key > arg2) {
                arg1 = v1;
                continue
            };
            v0 = v1 + 1;
        };
        arg1
    }
    
    public(friend) fun change_params<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64, arg6: u64) {
        check_map_params(arg1, arg2, arg3, arg4, arg5, arg6);
        assert!(arg0.size > 3, perpetual_v3::errors::map_too_small());
        assert!(arg1 <= arg0.branch_min && arg0.branch_max <= arg3, perpetual_v3::errors::invalid_map_parameters());
        assert!(arg4 <= arg0.leaf_min && arg0.leaf_max <= arg6, perpetual_v3::errors::invalid_map_parameters());
        arg0.branch_min = arg1;
        arg0.branches_merge_max = arg2;
        arg0.branch_max = arg3;
        arg0.leaf_min = arg4;
        arg0.leaves_merge_max = arg5;
        arg0.leaf_max = arg6;
    }
    
    fun check_map_params(arg0: u64, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) {
        assert!(2 <= arg0 && arg0 <= arg2 / 2, perpetual_v3::errors::invalid_map_parameters());
        assert!(2 * arg0 <= arg1 && arg1 <= arg2, perpetual_v3::errors::invalid_map_parameters());
        assert!(2 <= arg3 && arg3 <= (arg5 + 1) / 2, perpetual_v3::errors::invalid_map_parameters());
        assert!(2 * arg3 - 1 <= arg4 && arg4 <= arg5, perpetual_v3::errors::invalid_map_parameters());
    }
    
    public(friend) fun clear<T0: copy + drop + store>(arg0: &mut Map<T0>) {
        let v0 = arg0.root;
        let v1 = v0;
        if (9223372036854775808 & v0 == 0) {
            let v2 = sui::dynamic_field::remove<u64, Branch>(&mut arg0.id, v1);
            let v3 = &v2.kids;
            let v4 = std::vector::length<u64>(v3) - 1;
            let v5 = *std::vector::borrow<u64>(v3, v4);
            v1 = v5;
            while (9223372036854775808 & v5 == 0) {
                let v6 = 0;
                loop {
                    if (v6 < v4) {
                        drop_branch<T0>(arg0, *std::vector::borrow<u64>(v3, v6));
                        v6 = v6 + 1;
                        continue
                    };
                };
            };
            drop_first_leaves<T0>(arg0, v4);
            arg0.root = v5;
        };
        clear_leaf<T0>(arg0, v1);
    }
    
    fun clear_leaf<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64) {
        let v0 = sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut arg0.id, arg1);
        v0.keys_vals = std::vector::empty<Pair<T0>>();
        arg0.size = arg0.size - std::vector::length<Pair<T0>>(&v0.keys_vals);
    }
    
    fun copy_slice<T0: copy + drop + store>(arg0: &vector<T0>, arg1: u64, arg2: u64) : vector<T0> {
        let v0 = std::vector::empty<T0>();
        while (arg1 < arg2) {
            std::vector::push_back<T0>(&mut v0, *std::vector::borrow<T0>(arg0, arg1));
            arg1 = arg1 + 1;
        };
        v0
    }
    
    fun cut_reversed_left<T0: copy + drop + store>(arg0: &mut vector<T0>, arg1: u64) : vector<T0> {
        let v0 = std::vector::empty<T0>();
        let v1 = arg1;
        while (v1 > 0) {
            let v2 = v1 - 1;
            v1 = v2;
            std::vector::push_back<T0>(&mut v0, *std::vector::borrow_mut<T0>(arg0, v2));
        };
        drop_left<T0>(arg0, arg1);
        v0
    }
    
    fun cut_reversed_left1<T0: copy + drop + store>(arg0: &mut vector<T0>, arg1: u64) : (T0, vector<T0>) {
        let v0 = std::vector::empty<T0>();
        let v1 = arg1 - 1;
        let v2 = v1;
        while (v2 > 0) {
            let v3 = v2 - 1;
            v2 = v3;
            std::vector::push_back<T0>(&mut v0, *std::vector::borrow_mut<T0>(arg0, v3));
        };
        drop_left<T0>(arg0, arg1);
        (*std::vector::borrow_mut<T0>(arg0, v1), v0)
    }
    
    fun cut_reversed_right<T0: copy + drop + store>(arg0: &mut vector<T0>, arg1: u64) : vector<T0> {
        let v0 = std::vector::empty<T0>();
        while (arg1 > 0) {
            std::vector::push_back<T0>(&mut v0, std::vector::pop_back<T0>(arg0));
            arg1 = arg1 - 1;
        };
        v0
    }
    
    fun cut_right<T0: copy + drop + store>(arg0: &mut vector<T0>, arg1: u64) : vector<T0> {
        let v0 = cut_reversed_right<T0>(arg0, arg1);
        reverse<T0>(&mut v0);
        v0
    }
    
    fun drop_branch<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64) {
        let v0 = sui::dynamic_field::remove<u64, Branch>(&mut arg0.id, arg1);
        let v1 = &v0.kids;
        let v2 = *std::vector::borrow<u64>(v1, 0);
        if (9223372036854775808 & v2 == 0) {
            drop_branch<T0>(arg0, v2);
            let v3 = 1;
            while (v3 < std::vector::length<u64>(v1)) {
                drop_branch<T0>(arg0, *std::vector::borrow<u64>(v1, v3));
                v3 = v3 + 1;
            };
            return
        };
        drop_first_leaves<T0>(arg0, std::vector::length<u64>(v1));
    }
    
    fun drop_first<T0: copy + drop + store>(arg0: &mut vector<T0>) {
        let v0 = std::vector::length<T0>(arg0);
        while (v0 > 1) {
            let v1 = v0 - 1;
            v0 = v1;
            std::vector::swap<T0>(arg0, 0, v1);
        };
        std::vector::pop_back<T0>(arg0);
    }
    
    fun drop_first_leaves<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64) {
        let v0 = 0;
        let v1 = arg0.first;
        while (arg1 > 0) {
            let v2 = sui::dynamic_field::remove<u64, Leaf<T0>>(&mut arg0.id, v1);
            v0 = v0 + std::vector::length<Pair<T0>>(&v2.keys_vals);
            v1 = v2.next;
            arg1 = arg1 - 1;
        };
        arg0.size = arg0.size - v0;
        arg0.first = v1;
    }
    
    fun drop_kids<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: bool, arg3: vector<u64>) {
        if (arg1 == 0) {
            return
        };
        if (arg2) {
            while (arg1 > 0) {
                arg1 = arg1 - 1;
                drop_branch<T0>(arg0, std::vector::pop_back<u64>(&mut arg3));
            };
        } else {
            drop_first_leaves<T0>(arg0, arg1);
        };
    }
    
    fun drop_left<T0: copy + drop + store>(arg0: &mut vector<T0>, arg1: u64) {
        let v0 = std::vector::length<T0>(arg0);
        if (2 * arg1 > v0) {
            *arg0 = copy_slice<T0>(arg0, arg1, v0);
            return
        };
        let v1 = arg1;
        while (v1 < v0) {
            std::vector::swap<T0>(arg0, v1 - arg1, v1);
            v1 = v1 + 1;
        };
        drop_right<T0>(arg0, arg1);
    }
    
    fun drop_right<T0: copy + drop + store>(arg0: &mut vector<T0>, arg1: u64) {
        while (arg1 > 0) {
            std::vector::pop_back<T0>(arg0);
            arg1 = arg1 - 1;
        };
    }
    
    fun drop_second<T0: copy + drop + store>(arg0: &mut vector<T0>) {
        let v0 = std::vector::length<T0>(arg0);
        while (v0 != 2) {
            let v1 = v0 - 1;
            v0 = v1;
            std::vector::swap<T0>(arg0, 1, v1);
        };
        std::vector::pop_back<T0>(arg0);
    }
    
    public(friend) fun find_leaf<T0: copy + drop + store>(arg0: &Map<T0>, arg1: u128) : u64 {
        let v0 = arg0.root;
        while (9223372036854775808 & v0 == 0) {
            let v1 = sui::dynamic_field::borrow<u64, Branch>(&arg0.id, v0);
            let v2 = &v1.keys;
            v0 = *std::vector::borrow<u64>(&v1.kids, binary_search(v2, std::vector::length<u128>(v2), arg1));
        };
        v0
    }
    
    public(friend) fun first_leaf_ptr<T0: copy + drop + store>(arg0: &Map<T0>) : u64 {
        arg0.first
    }
    
    public(friend) fun get_leaf<T0: copy + drop + store>(arg0: &Map<T0>, arg1: u64) : &Leaf<T0> {
        sui::dynamic_field::borrow<u64, Leaf<T0>>(&arg0.id, arg1)
    }
    
    public(friend) fun get_leaf_mut<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64) : &mut Leaf<T0> {
        sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut arg0.id, arg1)
    }
    
    public(friend) fun has_key<T0: copy + drop + store>(arg0: &Map<T0>, arg1: u128) : bool {
        let v0 = &sui::dynamic_field::borrow<u64, Leaf<T0>>(&arg0.id, find_leaf<T0>(arg0, arg1)).keys_vals;
        let v1 = std::vector::length<Pair<T0>>(v0);
        let v2 = binary_search_p<T0>(v0, v1, arg1);
        v2 < v1 && arg1 == std::vector::borrow<Pair<T0>>(v0, v2).key
    }
    
    fun increase_counter(arg0: &mut u64) : u64 {
        *arg0 = *arg0 + 1;
        *arg0
    }
    
    fun insert_into_leaf<T0: copy + drop + store>(arg0: &mut Leaf<T0>, arg1: u128, arg2: T0) : u64 {
        let v0 = &arg0.keys_vals;
        let v1 = std::vector::length<Pair<T0>>(v0);
        let v2 = binary_search_p<T0>(v0, v1, arg1);
        assert!(v2 == v1 || arg1 != std::vector::borrow<Pair<T0>>(v0, v2).key, perpetual_v3::errors::key_already_exists());
        let v3 = Pair<T0>{
            key : arg1, 
            val : arg2,
        };
        std::vector::insert<Pair<T0>>(&mut arg0.keys_vals, v3, v2);
        v1 + 1
    }
    
    public(friend) fun is_empty<T0: copy + drop + store>(arg0: &Map<T0>) : bool {
        arg0.size == 0
    }
    
    fun last<T0: copy + drop + store>(arg0: &vector<T0>) : &T0 {
        std::vector::borrow<T0>(arg0, std::vector::length<T0>(arg0) - 1)
    }
    
    public(friend) fun leaf_elem<T0: copy + drop + store>(arg0: &Leaf<T0>, arg1: u64) : (u128, &T0) {
        let v0 = std::vector::borrow<Pair<T0>>(&arg0.keys_vals, arg1);
        (v0.key, &v0.val)
    }
    
    public(friend) fun leaf_elem_mut<T0: copy + drop + store>(arg0: &mut Leaf<T0>, arg1: u64) : (u128, &mut T0) {
        let v0 = std::vector::borrow_mut<Pair<T0>>(&mut arg0.keys_vals, arg1);
        (v0.key, &mut v0.val)
    }
    
    public(friend) fun leaf_find_index<T0: copy + drop + store>(arg0: &Leaf<T0>, arg1: u128) : u64 {
        let v0 = &arg0.keys_vals;
        binary_search_p<T0>(v0, std::vector::length<Pair<T0>>(v0), arg1)
    }
    
    public(friend) fun leaf_next<T0: copy + drop + store>(arg0: &Leaf<T0>) : u64 {
        arg0.next
    }
    
    public(friend) fun leaf_size<T0: copy + drop + store>(arg0: &Leaf<T0>) : u64 {
        std::vector::length<Pair<T0>>(&arg0.keys_vals)
    }
    
    fun merge_branches<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u128, arg3: u64) {
        let Branch {
            keys : v0,
            kids : v1,
        } = sui::dynamic_field::remove<u64, Branch>(&mut arg0.id, arg3);
        let v2 = v1;
        let v3 = v0;
        let v4 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg1);
        std::vector::push_back<u128>(&mut v4.keys, arg2);
        append_right<u128>(&mut v4.keys, &v3);
        append_right<u64>(&mut v4.kids, &v2);
    }
    
    fun merge_leaves<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u64) {
        let Leaf {
            keys_vals : v0,
            next      : v1,
        } = sui::dynamic_field::remove<u64, Leaf<T0>>(&mut arg0.id, arg2);
        let v2 = v0;
        let v3 = sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut arg0.id, arg1);
        append_right<Pair<T0>>(&mut v3.keys_vals, &v2);
        v3.next = v1;
    }
    
    fun migrate_to_left_branch<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u64, arg3: u128, arg4: u64) : u128 {
        let v0 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg4);
        let v1 = arg2 + std::vector::length<u64>(&v0.kids);
        if (v1 <= arg0.branches_merge_max) {
            merge_branches<T0>(arg0, arg1, arg3, arg4);
            return 0
        };
        let v2 = (v1 + 1) / 2 - arg2;
        let (v3, v4) = cut_reversed_left1<u128>(&mut v0.keys, v2);
        let v5 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg1);
        std::vector::push_back<u128>(&mut v5.keys, arg3);
        append_reversed_right<u128>(&mut v5.keys, v4);
        append_reversed_right<u64>(&mut v5.kids, cut_reversed_left<u64>(&mut v0.kids, v2));
        v3
    }
    
    fun migrate_to_left_branch1<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u64, arg3: u128, arg4: u64) : (u128, u128, u64) {
        let v0 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg4);
        let v1 = arg2 + std::vector::length<u64>(&v0.kids);
        if (v1 <= arg0.branches_merge_max) {
            let Branch {
                keys : v2,
                kids : v3,
            } = sui::dynamic_field::remove<u64, Branch>(&mut arg0.id, arg4);
            let v4 = v3;
            let v5 = v2;
            let v6 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg1);
            let v7 = &mut v6.keys;
            let v8 = &mut v6.kids;
            std::vector::push_back<u128>(v7, arg3);
            append_right<u128>(v7, &v5);
            append_right<u64>(v8, &v4);
            return (0, *std::vector::borrow_mut<u128>(v7, 0), *std::vector::borrow_mut<u64>(v8, 1))
        };
        let v9 = (v1 + 1) / 2 - arg2;
        let (v10, v11) = cut_reversed_left1<u128>(&mut v0.keys, v9);
        let v12 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg1);
        let v13 = &mut v12.keys;
        let v14 = &mut v12.kids;
        std::vector::push_back<u128>(v13, arg3);
        append_reversed_right<u128>(v13, v11);
        append_reversed_right<u64>(v14, cut_reversed_left<u64>(&mut v0.kids, v9));
        (v10, *std::vector::borrow_mut<u128>(v13, 0), *std::vector::borrow_mut<u64>(v14, 1))
    }
    
    fun migrate_to_left_leaf<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u64, arg3: u64) : u128 {
        let v0 = sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut arg0.id, arg3);
        let v1 = arg2 + std::vector::length<Pair<T0>>(&v0.keys_vals);
        if (v1 <= arg0.leaves_merge_max) {
            merge_leaves<T0>(arg0, arg1, arg3);
            return 0
        };
        let v2 = sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut arg0.id, arg1);
        append_reversed_right<Pair<T0>>(&mut v2.keys_vals, cut_reversed_left<Pair<T0>>(&mut v0.keys_vals, v1 / 2 - arg2));
        last<Pair<T0>>(&v2.keys_vals).key
    }
    
    fun migrate_to_right_branch<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u128, arg3: u64, arg4: u64) : u128 {
        let v0 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg1);
        let v1 = std::vector::length<u64>(&v0.kids) + arg4;
        if (v1 <= arg0.branches_merge_max) {
            merge_branches<T0>(arg0, arg1, arg2, arg3);
            return 0
        };
        let v2 = v1 / 2 - arg4;
        let v3 = cut_right<u128>(&mut v0.keys, v2 - 1);
        let v4 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg3);
        std::vector::push_back<u128>(&mut v3, arg2);
        append_left<u128>(v3, &mut v4.keys);
        append_left<u64>(cut_right<u64>(&mut v0.kids, v2), &mut v4.kids);
        std::vector::pop_back<u128>(&mut v0.keys)
    }
    
    fun migrate_to_right_leaf<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u64, arg3: u64) : u128 {
        let v0 = sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut arg0.id, arg1);
        let v1 = std::vector::length<Pair<T0>>(&v0.keys_vals) + arg3;
        if (v1 <= arg0.leaves_merge_max) {
            merge_leaves<T0>(arg0, arg1, arg2);
            return 0
        };
        append_left<Pair<T0>>(cut_right<Pair<T0>>(&mut v0.keys_vals, v1 / 2 - arg3), &mut sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut arg0.id, arg2).keys_vals);
        last<Pair<T0>>(&v0.keys_vals).key
    }
    
    public(friend) fun min_key<T0: copy + drop + store>(arg0: &Map<T0>) : u128 {
        std::vector::borrow<Pair<T0>>(&sui::dynamic_field::borrow<u64, Leaf<T0>>(&arg0.id, arg0.first).keys_vals, 0).key
    }
    
    fun remove_at<T0: copy + drop + store>(arg0: &mut vector<T0>, arg1: u64) : T0 {
        let v0 = std::vector::length<T0>(arg0) - 1;
        while (v0 != arg1) {
            std::vector::swap<T0>(arg0, arg1, v0);
            v0 = v0 - 1;
        };
        std::vector::pop_back<T0>(arg0)
    }
    
    fun remove_from_branch<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u128) : (T0, u64) {
        let v0 = sui::dynamic_field::borrow<u64, Branch>(&arg0.id, arg1);
        let v1 = &v0.keys;
        let v2 = std::vector::length<u128>(v1);
        let v3 = binary_search(v1, v2, arg2);
        let v4 = &v0.kids;
        let v5 = *std::vector::borrow<u64>(v4, v3);
        if (9223372036854775808 & v5 == 0) {
            if (v3 < v2) {
                let v6 = v3 + 1;
                let (v7, v8) = remove_from_branch<T0>(arg0, v5, arg2);
                if (v8 < arg0.branch_min) {
                    update_after_migration<T0>(arg0, arg1, &mut v2, v3, migrate_to_left_branch<T0>(arg0, v5, v8, *std::vector::borrow<u128>(v1, v3), *std::vector::borrow<u64>(v4, v6)), v6);
                };
                return (v7, v2 + 1)
            };
            let v9 = v3 - 1;
            let (v10, v11) = remove_from_branch<T0>(arg0, v5, arg2);
            if (v11 < arg0.branch_min) {
                update_after_migration_last<T0>(arg0, arg1, &mut v2, v9, migrate_to_right_branch<T0>(arg0, *std::vector::borrow<u64>(v4, v9), *std::vector::borrow<u128>(v1, v9), v5, v11));
            };
            return (v10, v2 + 1)
        };
        if (v3 < v2) {
            let v12 = v3 + 1;
            let (v13, v14) = remove_from_leaf<T0>(arg0, v5, arg2);
            if (v14 < arg0.leaf_min) {
                update_after_migration<T0>(arg0, arg1, &mut v2, v3, migrate_to_left_leaf<T0>(arg0, v5, v14, *std::vector::borrow<u64>(v4, v12)), v12);
            };
            return (v13, v2 + 1)
        };
        let v15 = v3 - 1;
        let (v16, v17) = remove_from_leaf<T0>(arg0, v5, arg2);
        if (v17 < arg0.leaf_min) {
            update_after_migration_last<T0>(arg0, arg1, &mut v2, v15, migrate_to_right_leaf<T0>(arg0, *std::vector::borrow<u64>(v4, v15), v5, v17));
        };
        (v16, v2 + 1)
    }
    
    fun remove_from_leaf<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: u128) : (T0, u64) {
        let v0 = sui::dynamic_field::borrow_mut<u64, Leaf<T0>>(&mut arg0.id, arg1);
        let v1 = &v0.keys_vals;
        let v2 = std::vector::length<Pair<T0>>(v1);
        let v3 = remove_at<Pair<T0>>(&mut v0.keys_vals, binary_search_p<T0>(v1, v2, arg2));
        assert!(arg2 == v3.key, perpetual_v3::errors::key_not_exist());
        arg0.size = arg0.size - 1;
        (v3.val, v2 - 1)
    }
    
    fun reverse<T0: copy + drop + store>(arg0: &mut vector<T0>) {
        let v0 = std::vector::length<T0>(arg0);
        if (v0 <= 1) {
            return
        };
        let v1 = v0 / 2;
        while (v1 > 0) {
            let v2 = v1 - 1;
            v1 = v2;
            std::vector::swap<T0>(arg0, v2, v0 - 1 - v2);
        };
    }
    
    public(friend) fun size<T0: copy + drop + store>(arg0: &Map<T0>) : u64 {
        arg0.size
    }
    
    fun split_branch(arg0: &mut Branch, arg1: &mut u64, arg2: u64) : (u64, u128, Branch) {
        let v0 = arg2 >> 1;
        let v1 = Branch{
            keys : cut_right<u128>(&mut arg0.keys, v0 - 1), 
            kids : cut_right<u64>(&mut arg0.kids, v0),
        };
        (increase_counter(arg1), std::vector::pop_back<u128>(&mut arg0.keys), v1)
    }
    
    fun split_leaf<T0: copy + drop + store>(arg0: &mut Leaf<T0>, arg1: &mut u64, arg2: u64) : (u64, u128, Leaf<T0>) {
        let v0 = arg2 >> 1;
        let v1 = 9223372036854775808 | increase_counter(arg1);
        arg0.next = v1;
        let v2 = Leaf<T0>{
            keys_vals : cut_right<Pair<T0>>(&mut arg0.keys_vals, v0), 
            next      : arg0.next,
        };
        (v1, std::vector::borrow<Pair<T0>>(&arg0.keys_vals, arg2 - v0 - 1).key, v2)
    }
    
    fun update_after_migration<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: &mut u64, arg3: u64, arg4: u128, arg5: u64) {
        let v0 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg1);
        if (arg4 == 0) {
            remove_at<u128>(&mut v0.keys, arg3);
            remove_at<u64>(&mut v0.kids, arg5);
            *arg2 = *arg2 - 1;
            return
        };
        *std::vector::borrow_mut<u128>(&mut v0.keys, arg3) = arg4;
    }
    
    fun update_after_migration_last<T0: copy + drop + store>(arg0: &mut Map<T0>, arg1: u64, arg2: &mut u64, arg3: u64, arg4: u128) {
        let v0 = sui::dynamic_field::borrow_mut<u64, Branch>(&mut arg0.id, arg1);
        if (arg4 == 0) {
            std::vector::pop_back<u128>(&mut v0.keys);
            std::vector::pop_back<u64>(&mut v0.kids);
            *arg2 = *arg2 - 1;
            return
        };
        *std::vector::borrow_mut<u128>(&mut v0.keys, arg3) = arg4;
    }
    
    // decompiled from Move bytecode v6
}

