

type Information <: Resource
    allowed_access :: Vector{ASCIIString}
end

type Computer <: Resource
    contents :: Location
end

Computer(name :: ASCIIString) = Computer(Location(name))

type PortableMedia <: Resource
    contents :: Location
end

PortableMedia(name :: ASCIIString) = PortableMedia(Location(name))

type Employee <: Agent
    data :: AgentData
end
Employee(name :: ASCIIString) = Employee(AgentData(name))


type Leader <: Agent
    data :: AgentData
end
Leader(name ::ASCIIString) = Leader(AgentData(name))

type Attacker <: Agent
    data :: AgentData
end
Attacker(name ::ASCIIString) = Attacker(AgentData(name))

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
