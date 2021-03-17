

module SysModels

    #import Base.Collections.PriorityQueue, Base.Collections.peek, Base.Collections.dequeue!
    import DataStructures.PriorityQueue, DataStructures.peek, DataStructures.dequeue!, DataStructures.enqueue!
    import Base.Order
    using JSON
    using Distributions

    const seconds = 1.0
    const minutes = 60seconds
    const hours = 60minutes
    const days = 24hours
    export seconds, minutes, hours, days

    const LOG_OFF = 0
    const LOG_MIN = 1
    const LOG_MAX = 10

    tmp_jsloglevel = LOG_OFF

    if haskey(ENV, "JSLOGLEVEL")
        global tmp_jsloglevel = parse(Int64, ENV["JSLOGLEVEL"]) 
    end

    const jsloglevel = tmp_jsloglevel

    println(jsloglevel)
    
    abstract type Resource end


    include("vis/vis.jl")
    include("simulation.jl")
    include("process.jl")
    include("model.jl")
    include("agent.jl")
    include("location.jl")
    include("resources.jl")
    include("observation.jl")

    include("door.jl")
    include("choice.jl")



    export Simulation, Model, Resource, Process, Location, InputLocation, OutputLocation, Interface, Store
    export Agent, AgentData, get_data


    export link, enable_link, disable_link
    export move, claim, release, distrib, add, remove, find, flatten, get_store, create_store, changed_property
    export start, hold, sleep, now, time_of_day
    export get_location, get_func, get_funcs, get_model
    export run, compose

    export @claim, ClaimTree, ClaimTreeNode

    export Door, access

    export choose, choose_stochastic

    #observation.jl
    export Event, ignore, handle!, handler, handled, observe, startevent, stopevent

    # js logging for traces
    export LOG_OFF, LOG_MIN, LOG_MAX, @jslog, jslog, jslog_init, jslog_end

    #export show

end
