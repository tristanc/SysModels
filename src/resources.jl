

function byres(res :: Resource)

    function find_res(resources)

        ix = findfirst(x -> x == res, resources)

        if ix != nothing && ix > 0
            return true, Resource[resources[ix]]
        else
            return false, Resource[]
        end

    end
    return find_res
end

function byres(res :: Vector{Resource})

    function find_res(resources :: Vector{Resource})

        isect = intersect(res, resources)

        if length(isect) == length(res)
            return true, res
        else
            return false, isect
        end

    end
    return find_res
end

function bytype(t :: Type, count :: Int64 = 1)
    function find_res(resources)
        filtered = filter(a -> isa(a, t), resources)
        if length(filtered) >= count && length(filtered) > 0
            if count == 0
                return true, filtered
            else
                return true, filtered[1:count]
            end
        else
            return false, filtered
        end
    end
    return find_res
end

function bytype(t :: Type, min :: Int64, max :: Int64)
    function find_res(resources)
        filtered = filter(a -> isa(a, t), resources)
        if length(filtered) >= min
            count = length(filtered)
            if count > max
                count = max
            end
            return true, filtered[1:count]
        else
            return false, filtered
        end
    end
    return find_res
end

function find(f :: Function, count :: Int64 = 1)
    function find_res(resources)
        filtered = filter(f, resources)
        if length(filtered) > 0
            if count == 0
                return true, filtered
            else
                return true, filtered[1:count]
            end
        else
            return false, filtered
        end
    end
    return find_res
end

flatten(a::Array{T,1}) where T = any(map(x->isa(x,Array),a)) ? flatten(vcat(map(flatten,a)...)) : a
flatten(a::Array{T}) where T = reshape(a,prod(size(a)))
flatten(a)=a

function flatten(collection :: Dict{Store, Vector{Resource}})
    flatten(collect(values(collection)))
end

mutable struct ClaimTreeNode
    leaf :: Bool
    store :: Store
    find_wanted :: Function
    operation :: Symbol
    children :: Vector{ClaimTreeNode}

    function ClaimTreeNode(store :: Store, find_wanted :: Function)
        ctn = new()
        ctn.leaf = true
        ctn.store = store
        ctn.find_wanted = find_wanted
        return ctn
    end

    function ClaimTreeNode(store :: Store, resource :: Resource)
        return ClaimTreeNode(store, byres(resource))
    end

    function ClaimTreeNode(store :: Store, resources :: Vector{Resource})
        return ClaimTreeNode(store, byres(resources))
    end

    function ClaimTreeNode(store :: Store, t :: Type)
        return ClaimTreeNode(store, bytype(t))
    end

    function ClaimTreeNode(store :: Store, t :: Type, count :: Int64)
        return ClaimTreeNode(store, bytype(t, count))
    end

    function ClaimTreeNode(op :: Symbol, left :: ClaimTreeNode, right :: ClaimTreeNode)
        ctn = new()
        ctn.leaf = false
        ctn.operation = op
        ctn.children = ClaimTreeNode[left,right]
        return ctn
    end

end

function get_stores_node(node :: ClaimTreeNode)
    if node.leaf
        return [node.store]
    else
        stores = Store[]
        for child in node.children
            stores = union(stores, get_stores_node(child))
        end
        return stores
    end
end

mutable struct ClaimTree
    head :: ClaimTreeNode
    stores :: Vector{Store}
    proc :: Process
    claimed :: Dict{Store, Vector{Resource}}
    cached :: Dict{Store, Vector{Resource}}

    function ClaimTree(proc :: Process, head :: ClaimTreeNode)
        ct = new()
        ct.head = head
        ct.proc = proc
        ct.stores = get_stores_node(head)
        ct.claimed = Dict{Store, Vector{Resource}}()
        ct.cached = Dict{Store, Vector{Resource}}()
        return ct
    end

end

function get_stores(tree :: ClaimTree)
    return tree.stores
end

function satisfied_node(node :: ClaimTreeNode, available :: Dict{Store, Vector{Resource}})

    if node.leaf

        #this is a leaf node
        avail = available[node.store]

        satisfied, used = node.find_wanted(avail)
        used_dict = Dict{Store, Vector{Resource}}()
        used_dict[node.store] = used

        return satisfied, used_dict
    else

        if node.operation == :||
            #or
            used_all = Dict{Store, Vector{Resource}}()
            for child in node.children
                satisfied, used = satisfied_node(child, available)
                if satisfied
                    return true, used
                else
                    for k in union(keys(used_all), keys(used))
                        used_all[k] = union(get(used_all, k, Resource[]), get(used, k, Resource[]))
                    end
                end
            end
            return false, used_all
        else
            #and
            used_all = Dict{Store, Vector{Resource}}()
            avail = copy(available)
            all_satisfied = true
            for child in node.children
                satisfied, used = satisfied_node(child, avail)
                if !satisfied
                    all_satisfied = false
                end

                for k in union(keys(used_all), keys(used))
                    used_all[k] = union(get(used_all, k, Resource[]), get(used, k, Resource[]))
                end

                for k in keys(used)
                    avail[k] = setdiff(avail[k], used[k])
                end

            end

            return all_satisfied, used_all
        end

    end

end

function satisfied_tree(tree :: ClaimTree, available :: Dict{Store, Vector{Resource}})

    satisfied, used = satisfied_node(tree.head, available)

    tree.cached = used

    if satisfied
        tree.claimed = copy(used)
    end

    return satisfied, tree.claimed

end




function get_touched_stores(store :: Store, found :: Vector{Store} = Store[])
    push!(found, store)
    for t in keys(store.get_queue)
        for ts in t.stores
            if !in(ts, found)
                get_touched_stores(ts, found)
            end
        end
    end
    return found
end


function updated_store(store :: Store)
    touched = get_touched_stores(store)
    avail = Dict{Store, Vector{Resource}}()

    for ts in touched
        avail[ts] = copy(ts.resources)
    end

    #now go through trees in order
    for tree in keys(store.get_queue)

        #in each of the other stores touched by this tree
        #remove the cached resources from avail for
        #the trees that are not in this store
        for other_store in tree.stores
            if other_store == store
                continue
            end

            for other_tree in keys(other_store.get_queue)
                if other_tree == tree
                    break
                end
                if !in(other_tree, keys(store.get_queue))
                    for k in keys(other_tree.cached)
                        avail[k] = setdiff(get(avail, k, Resource[]), other_tree.cached[k])
                    end
                end
            end
        end

        satisfied, used = satisfied_tree(tree, avail)
        if satisfied

            wake(tree.proc)
        end
        for k in keys(used)
            avail[k] = setdiff(get(avail, k, Resource[]), used[k])
        end
    end

end




function check_new_claim(tree :: ClaimTree)

    s :: Store = tree.stores[1]
    touched_stores = get_touched_stores(s)
    avail = Dict{Store, Vector{Resource}}()

    for ts in touched_stores
        avail[ts] = copy(ts.resources)
    end

    for store in tree.stores
        for other_tree in keys(store.get_queue)
            if other_tree == tree
                break
            end
            avail[store] = setdiff(get(avail, store, Resource[]), get(other_tree.cached, store, Resource[]))
        end
    end

    return satisfied_tree(tree, avail)

end

function insert_priority(tree :: ClaimTree)
    s :: Store = tree.stores[1]
    touched_stores = get_touched_stores(s)
    avail = Dict{Store, Vector{Resource}}()

    touched_trees = []

    for ts in touched_stores
        append!(touched_trees, keys(store.get_queue))
    end

    for t in unique!(touched_trees)
        check_new_claim(t)
    end

end

function claim(tree :: ClaimTree, timeout :: Float64 = -1.0 ; priority :: Float64 = 100.0 )

    for store in tree.stores
        #push!(store.get_queue, tree)
        enqueue!(store.get_queue, tree, priority)

        # TODO make sure switch to PQ doesn't mess everything up
    end


    satisfied, used = check_new_claim(tree)

    if priority < 100
        insert_priority(tree)
    end
    # for store in tree.stores
    #     if priority < maximum(values(store.get_queue))
    #         insert_priority(tree)
    #         break
    #     end
    # end


    if satisfied

        #remove from get_queues
        for store in tree.stores
            #pop!(store.get_queue)
            delete!(store.get_queue, tree)
            if haskey(used, store)
                idx = filter(p-> p!= nothing, indexin(used[store], store.resources))
                sort!(idx)
                deleteat!(store.resources, idx)
            end
        end

        x = Resource[]
        for v in values(used)
            append!(x,v)
        end

        #add to list of claimed items for this process
        append!(tree.proc.claimed_resources, x)

        return true, used
    else


        if timeout >= 0.0
          hold(tree.proc, timeout)
        else
          sleep(tree.proc)
        end


        #remove from stores' get_queues.
        for store in tree.stores
            #deleteat!(store.get_queue, findall( fx -> fx == tree, store.get_queue))
            delete!(store.get_queue, tree)
        end


        if length(tree.claimed) > 0

            #add to list of claimed items for this process
            x = Resource[]
            for v in values(tree.claimed)
                append!(x,v)
            end

            append!(tree.proc.claimed_resources, x)


            #remove taken resources
            for store in keys(tree.claimed)
                #deleteat!(store.resources, findin(store.resources, tree.claimed[store]))
                idx = filter(p-> p!= nothing, indexin(tree.claimed[store], store.resources))
                sort!(idx)
                deleteat!(store.resources, idx)
            end


            return true, tree.claimed
        else

            return false, tree.claimed
        end

    end

end


macro claim(p, ex, timeout...)

    function build_tree(exp)

        if exp.head == :tuple
            #tuple, so end node
            if length(exp.args) == 2
                arg1 = exp.args[1]
                arg2 = exp.args[2]
                return :(ClaimTreeNode(get_store($(esc(arg1)), "default"), $(esc(arg2))))
            elseif length(exp.args) == 3
                arg1 = exp.args[1]
                arg2 = exp.args[2]
                arg3 = exp.args[3]
                if typeof(arg3) == String
                    return :(ClaimTreeNode(get_store($(esc(arg1)), $(esc(arg3))), $(esc(arg2))))
                else
                    return :(ClaimTreeNode(get_store($(esc(arg1)), "default"), $(esc(arg2)), $(esc(arg3))))
                end
            end
        elseif exp.head == :(&&) || exp.head == :(||)
            lexp = build_tree(exp.args[1])
            rexp = build_tree(exp.args[2])
            op = string(exp.head)
            return :(ClaimTreeNode(Symbol($(esc(op))), $lexp, $rexp))
        end
    end

    head = build_tree(ex)
    tree = :(ClaimTree($(esc(p)), $head))
    local ret
    if isempty(timeout)
      ret = :(claim($tree))
    else
      to = timeout[1]
      ret = :(claim($tree, $(esc(to))))
    end
    return ret
end

function release(proc :: Process, loc :: Location, resources :: Vector{Resource}, store_name :: String = "default")
    #local sim :: Simulation = proc.simulation
    store = loc.stores[store_name]
    append!(store.resources, resources)
    deleteat!(proc.claimed_resources, findall( fx -> fx in resources, proc.claimed_resources))
    updated_store( store)
end

function release(proc :: Process, loc :: Location, resource :: Resource, store_name :: String = "default")
    #local sim :: Simulation = proc.simulation
    store = loc.stores[store_name]
    push!(store.resources, resource)
    deleteat!(proc.claimed_resources, findfirst(x -> x == resource, proc.claimed_resources))
    updated_store( store)
end


function toJSON(resource :: Resource)
    return Dict{Any,Any}(
        "id" => string(objectid(resource)),
        "type" => string(typeof(resource))
    )
end
