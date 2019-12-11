
function get_store(loc :: Location, store_name :: String = "default")
    return loc.stores[store_name]
end

function single_link(from :: Location, to :: Location, enabled :: Bool = true)
    from.links[to] = enabled
end

function link(one :: Location, two :: Location, enabled :: Bool = true)
    single_link(one, two, enabled)
    single_link(two, one, enabled)
end

function single_unlink(from :: Location, to :: Location)
    delete!(from.links, to)
end

function unlink(one :: Location, two :: Location)
    single_unlink(one, two)
    single_unlink(two, one)
end

function enable_link(from :: Location, to :: Location)
        from.links[to] = true
end

function disable_link(from :: Location, to :: Location)
        from_links[to] = false
end

function move_allowed(from :: Location, to :: Location)
    return get(from.links, to, false)
end

function distrib(resource :: Resource, loc :: Location, store_name = "default")
    push!(loc.resources, resource)

    s = loc.stores[store_name]
    push!(s.resources, resource)
end

function distrib(resources :: Vector{Resource}, loc :: Location, store_name = "default")
    append!(loc.resources, resources)

    s = loc.stores[store_name]
    append!(s.resources, resources)
end

function add(proc :: Process, resource :: Resource, loc :: Location, store_name :: String = "default")
    push!(loc.resources, resource)

    @jslog(LOG_MIN, proc.simulation, Dict{Any,Any}(
        "time" => now(proc.simulation),
        "type" => "add-resource",
        "resource" => toJSON(resource),
        "location" => string(object_id(loc))
    ))

    s = loc.stores[store_name]
    push!(s.resources, resource)
    updated_store(proc.simulation, s)
end

function add(proc :: Process, agent :: Agent, loc :: Location, store_name :: String = "default")

    #call normal add function
    invoke(add, Tuple{Process, Resource, Location, String}, proc, agent, loc, store_name)

    #creates a link from what the agent is carrying to the location the agent is in
    carrying = get_data(agent).carrying
    link(loc, carrying)

end

function add(proc :: Process, resources :: Vector{Resource}, loc :: Location, store_name :: String = "default")
    for r in resources
        add(proc, r, loc, store_name)
    end
end


function remove(proc :: Process, resource :: Resource, loc :: Location, store_name = "default")
    if !in(resource, proc.claimed_resources)
        error("Trying to remove resource not owned by process.")
    end

    @jslog(LOG_MIN, proc.simulation, Dict{Any,Any}(
        "time" => now(proc.simulation),
        "type" => "remove-resource",
        "id" => string(object_id(resource)),
        "location" => string(object_id(loc))
    ))

    deleteat!(loc.resources, findfirst(x -> x == resource, loc.resources))
    deleteat!(proc.claimed_resources, findfirst(x -> x == resource, proc.claimed_resources))
end

function remove(proc :: Process, resources :: Vector{Resource}, loc :: Location, store_name = "default")
    for r in resources
        remove(proc, r, loc, store_name)
    end
end

function move(proc :: Process, resource :: Resource, from :: Location, to :: Location)

    if !move_allowed(from, to)
        error("No link or link disabled.")
    end

    if !in(resource, proc.claimed_resources)
        error("Trying to move resource not owned by process.")
    end

    @jslog(LOG_MIN, proc.simulation, Dict{Any,Any}(
        "time" => now(proc.simulation),
        "type" => "move-resource",
        "id" => string(object_id(resource)),
        "from" => string(object_id(from)),
        "to" => string(object_id(to))
    ))

    deleteat!(from.resources, findfirst(x -> x==resource, from.resources))
    push!(to.resources, resource)
end

function move(proc :: Process, agent :: Agent, from :: Location, to :: Location)

    # call the normal move function
    invoke(move, Tuple{Process, Resource, Location, Location}, proc, agent, from, to)

    #create links to agent's locations
    #and remove links from last location
    carrying= get_data(agent).carrying
    unlink(from, carrying)
    link(to, carrying)

end

function move(proc :: Process, resources :: Vector{Resource}, from :: Location, to :: Location)

    if !move_allowed(from, to)
        error("No link or link disabled.")
    end

    if in(0, indexin(resources, proc.claimed_resources))
            error("Trying to move resource not owned by process.")
    end

    if in(0, indexin(resources, from.resources))
            error("Trying to move resource from wrong location.")
    end

    @iflog(LOG_MIN, begin
        for res in resources
            jslog(proc.simulation, Dict{Any,Any}(
                "time" => now(proc.simulation),
                "type" => "move-resource",
                "id" => string(object_id(res)),
                "from" => string(object_id(from)),
                "to" => string(object_id(to))
            ))
        end
    end)


    deleteat!(from.resources, findall(x -> x in resources, from.resources))
    append!(to.resources, resources)
end



function toJSON(loc :: Location)
    return merge( Dict{Any,Any}(
        "id" => string(object_id(loc)),
        "name" => loc.name
    ), loc.js_properties)
end
