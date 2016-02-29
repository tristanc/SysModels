
abstract Agent <: Resource


type AgentData
    name :: ASCIIString
    carrying :: Location
    data :: Dict{Any, Any}
end

AgentData(name :: ASCIIString) = AgentData(name, Location("carrying: $name"), Dict{Any, Any}())

get_data(agent :: Agent) = agent.data

function toJSON(agent :: Agent)
    return Dict{Any,Any}(
        "id" => string(object_id(agent)),
        "type" => string(typeof(agent)),
        "name" => agent.data.name,
        "carrying" => string(object_id(agent.data))
    )
end
