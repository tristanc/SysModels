
"Resource representing an ongoing event."
mutable struct Event <: Resource
    loc :: Location
    origin :: Process
    handler :: Union{Process,Nothing}
    seenby :: Vector{ Process }
    data :: Dict{AbstractString, Any}
end

Event(loc :: Location, proc :: Process) = Event(loc, proc, Nullable{Process}(), Process[], Dict{AbstractString, Any}())
Event(loc :: Location, proc :: Process, data :: Dict{AbstractString, Any}) = Event(loc, proc, nothing, Process[], data)

"Ignore an event and add proc to this event's seenby vector."
function ignore(e :: Event, proc :: Process)
    push!(e.seenby, proc)
    release(proc, e.loc, e)
    return nothing
end

"Ignore multiple events."
function ignore( evts :: Vector{Event}, proc:: Process )
    for e in evts
        ignore(e,proc)
    end
    return nothing
end


function handle!(e :: Event, proc :: Process)
    e.handler = proc
    push!(e.seenby, proc)
    release(proc, e.loc, e)
    return nothing
end

function handle!(e :: Event, proc :: Process, agent :: Agent)
    handle!(e, proc)
    e.data["handle_agent"] = agent
    return nothing
end

function handler(e :: Event)
    return get(e.handler, nothing)
end

function handled(e :: Event)
    return e.handler != nothing
end

function observe(loc :: Location, proc :: Process, timeout = 0.0, conditions = res->true)

    # find events that have not been handled, that this proc hasn't seen, that meet conditions (if any)
    f = find( res -> isa(res, Event) && !handled(res) && ! (proc in res.seenby) && conditions(res))
    success, claimed = @claim(proc, (loc, f), timeout)

    if success
        return success, flatten(claimed)
    else
        return success, nothing
    end

end

function observe_handled(loc :: Location, proc :: Process, timeout = 0.0, conditions = res->true)

    # find events that have not been handled, that this proc hasn't seen, that meet conditions (if any)
    f = find( res -> isa(res, Event) && ! (proc in res.seenby) && conditions(res))
    success, claimed = @claim(proc, (loc, f), timeout)

    if success
        return success, flatten(claimed)
    else
        return success, nothing
    end

end

function startevent(loc :: Location, proc :: Process, data :: Dict{AbstractString,Any})
    # create event, move it its location
    println("startevent")
    e = Event(loc, proc, data)
    add(proc, e, loc)
    return e
end

function startevent(loc :: Location, proc :: Process, agent :: Agent)
    e = startevent(loc, proc, Dict{AbstractString,Any}("agent"=>agent))
    return e
end

function startevent(loc :: Location, proc :: Process)
    e = startevent(loc, proc, Dict{AbstractString,Any}())
    return e
end



function stopevent(proc :: Process,e :: Event)
    # claim event from location, remove it
    success, claimed = @claim(proc, (e.loc, e))

    if success
        remove(proc, e, e.loc)
    else
        #TODO throw error?
    end

    return e
end
