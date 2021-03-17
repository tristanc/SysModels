
abstract type Agent <: Resource end


mutable struct AgentData
    name :: String
    carrying :: Location
    data :: Dict{Any, Any}
end

AgentData(name :: String) = AgentData(name, Location("carrying: $name"), Dict{Any, Any}())

get_data(agent :: Agent) = agent.data

function toJSON(agent :: Agent)
    return Dict{Any,Any}(
        "id" => string(objectid(agent)),
        "type" => string(typeof(agent)),
        "name" => agent.data.name,
        "carrying" => string(objectid(agent.data))
    )
end
