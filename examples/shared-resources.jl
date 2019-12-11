

mutable struct Information <: Resource
    allowed_access :: Vector{String}
end

mutable struct Computer <: Resource
    contents :: Location
end

Computer(name :: String) = Computer(Location(name))

mutable struct PortableMedia <: Resource
    contents :: Location
end

PortableMedia(name :: String) = PortableMedia(Location(name))

mutable struct Employee <: Agent
    data :: AgentData
end
Employee(name :: String) = Employee(AgentData(name))


mutable struct Leader <: Agent
    data :: AgentData
end
Leader(name ::String) = Leader(AgentData(name))

mutable struct Attacker <: Agent
    data :: AgentData
end
Attacker(name ::String) = Attacker(AgentData(name))

function create_agents(model :: Model)

    employees = Employee[]
    leaders = Leader[]
    attackers = Attacker[]

    for i = 1 : model.params["num_groups"]

        for j = 1 : model.params["employees_per_group"]
            emp = Employee("employee $i,$j")
            emp_data = get_data(emp)
            emp_data.data["group"] = "group $i"
            emp_data.data["email"] = Location("email")
            emp_data.data["use_public_transport"] = rand() < model.params["p_public_transport"]

            prefs = [rand(model.params["dist_prod"]), rand(model.params["dist_sec"])]
            emp_data.data["preferences"] = prefs



            push!(employees, emp)
        end

        #create leader for the group
        emp = Leader("leader $i")
        emp_data = get_data(emp)
        emp_data.data["group"] = "group $i"
        emp_data.data["email"] = Location("email")
        emp_data.data["use_public_transport"] = rand() < model.params["p_public_transport"]

        prefs = [rand(model.params["dist_prod"]), rand(model.params["dist_sec"])]
        emp_data.data["preferences"] = prefs

        push!(leaders, emp)

    end

    for i = 1 : model.params["num_attackers"]
        agent = Attacker("attacker $i")
        push!(attackers, agent)
    end

    model.data["employees"] = employees
    model.data["leaders"] = leaders
    model.data["attackers"] = attackers

end
