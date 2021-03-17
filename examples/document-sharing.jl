
# using SecSim
#
# include("shared-resources.jl")

mutable struct Group
    name :: String
    share :: Location
    members :: Vector{Employee}

    function Group(name :: String)
        g = new()
        g.name = name
        g.share = Location("group-share: $name")
        g.members = Employee[]
        return g
    end
end

mutable struct AccessProblem <: Resource
    group :: Group
    employee :: Employee
end

function create_document_sharing_model()



    local groups = Dict{String, Group}()


    local signals = Location("signals")
    local global_share = Location("global_share")

    local loc_atrium :: Location
    local loc_office  = Location("Office")


    function leader_process(proc :: Process, leader :: Leader)
        move(proc, leader, loc_atrium, loc_office)

        model = get_model(proc)

        #get agent data
        data = get_data(leader)
        group_name = data.data["group"]
        group = groups[group_name]

        hold(proc, 20minutes)

        home_time = now(proc) + 8hours

        while now(proc) < home_time

            #create information with group-level access
            info = Information([group_name])

            #move info to group share
            add(proc, info, group.share)

            #check to see if there is a problem
            f = find( res -> isa(res, AccessProblem) && res.group == group, 0 )
            success, claimed = @claim(proc, (signals, f), 0.0)

            if success
                #someone has an access problem
                #distribute data another way
                problems = flatten(claimed)
                #choice = choose(leader, :global, :email, :dvd)

                choices = Dict{Symbol, Vector{Float64}}(:global => [1.0, 1.0], :email => [1.0, 1.0], :media => [2.9,2.9])
                choice = choose_stochastic(leader, choices)

                @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
                    "time" => now(proc.simulation),
                    "type" => "choice",
                    "id" => string(objectid(leader)),
                    "value" => string(choice)
                ))

                if choice == :global
                    #add info to global share
                    #println(" -> global")
                    add(proc, info, global_share)
                    model.data["to_global"] += 1
                    #@claim(proc, (global_share, info))
                elseif choice == :email
                    #email file to each employee
                    #println(" -> email")
                    model.data["to_email"] += 1
                    hold(proc, 3minutes)
                    for p in problems

                        emp_data = get_data(p.employee)
                        emp_email = emp_data.data["email"]
                        add(proc, info, emp_email)
                    end
                else
                    #use portable media (like dvd/usb stick) for each employee
                    #println(" -> media")
                    model.data["to_media"] += 1

                    for p in problems
                        hold(proc, 2minutes)
                        media = PortableMedia("media")

                        add(proc, info, media.contents)

                        #now give dvd to employee
                        emp_data = get_data(p.employee)
                        add(proc, media, emp_data.carrying)
                    end

                    #remove the signals
                    remove(proc, problems, signals)

                end

            end

            #claim info so processes don't see it again
            @claim(proc, (group.share, info))

            #wait a bit, then create more info
            hold(proc, 20minutes)

        end

        #go back to the atrium at the end of the day
        move(proc, leader, loc_office, loc_atrium)

    end

    function launch_leader_process(proc :: Process, leader :: Leader)
        @claim(proc, (loc_atrium, leader))
        leader_process(proc, leader)
    end

    function employee_process(proc :: Process, employee :: Employee)

        emp_data = get_data(employee)
        group_name = emp_data.data["group"]
        group = groups[group_name]

        #move employee to office
        move(proc, employee, loc_atrium, loc_office)

        home_time = now(proc) + 8hours

        has_problem = rand() <= .1

        while now(proc) < home_time

            timeout = home_time - now(proc)

            if has_problem

                @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
                    "time" => now(proc.simulation),
                    "type" => "event",
                    "id" => string(objectid(employee)),
                    "value" => "Can't access group share."
                ))

                ap = AccessProblem(group, employee)
                add(proc, ap, signals)
                email = emp_data.data["email"]
                success, claimed = @claim(proc, (global_share, Information) || (emp_data.carrying, PortableMedia) || (email, Information), timeout)

                if success
                    if haskey(claimed, get_store(global_share))
                        #println("  from global share")
                        release(proc, global_share, flatten(claimed))

                    elseif haskey(claimed, get_store(email))
                        #println("  from email")
                        release(proc, email, flatten(claimed))
                    else

                        #now leave it on the desk

                        move(proc, flatten(claimed), emp_data.carrying, loc_office)
                        release(proc, loc_office, flatten(claimed))

                    end

                    hold(proc, 1hours)
                end
            else
                success, claimed = @claim(proc, (group.share, Information), timeout)
                if success
                    #println("  received info")
                    info = flatten(claimed)
                    #do something with info... copy it?
                    #and then release
                    release(proc, group.share, info)

                    hold(proc, 1hours)
                end


            end

        end

        move(proc, employee, loc_office, loc_atrium)
    end

    function launch_employee_process(proc :: Process, employee :: Employee)
        @claim(proc, (loc_atrium, employee))
        employee_process(proc, employee)
    end

    function attacker_process(proc :: Process, agent :: Attacker)
        params = proc.simulation.model.params
        agent_data = get_data(agent)

        model = get_model(proc)

        #move to office
        move(proc, agent, loc_atrium, loc_office)

        #stay all day (probably should be shorter)
        leave_time = now(proc) + 8hours

        #now walk around trying to find media
        total_employees = params["num_groups"] * params["employees_per_group"]

        checked = 0
        store = get_store(loc_office)
        while now(proc) < leave_time
            hold(proc, 30seconds)

            #how many disks are lying around?
            num_media = length( Base.findall( (r) -> isa(r,PortableMedia), store.resources))
            if rand() < num_media / (total_employees - checked)
                #found a disk lying around, pick it up
                success, claimed = @claim(proc, (loc_office, PortableMedia))
                if success
                    model.data["attacker_found_media"] += 1
                    media = flatten(claimed)
                    move(proc, media, loc_office, agent_data.carrying)
                end
            end
            checked += 1
        end

        #move back to atrium
        move(proc, agent, loc_office, loc_atrium)

    end

    function launch_attacker_process(proc :: Process, agent :: Attacker)
        @claim(proc, (loc_atrium, agent))
        attacker_process(proc, agent)
    end

    function start_agents(proc :: Process)

        local sim :: Simulation = proc.simulation
        local model = sim.model

        for emp in model.data["employees"]
            emp_proc = Process("employee", (p) -> launch_employee_process(p, emp) )
            add(proc, emp, loc_atrium)
            start(proc, emp_proc, rand(1:1200)seconds)
        end

        for emp in model.data["leaders"]
            emp_proc = Process("leader", (p) -> launch_leader_process(p, emp) )
            add(proc, emp, loc_atrium)
            start(proc, emp_proc, rand(1:1200)seconds)
        end

        for emp in model.data["attackers"]
            att_proc = Process("attacker", (p) -> launch_attacker_process(p, emp))
            add(proc, emp, loc_atrium)
            start(proc, att_proc, rand(1:1200)seconds)
        end

    end

    model = Model()

    model.setup = (mod :: Model) -> begin
        loc_atrium  = get_location(mod, "Atrium")
        link(loc_atrium, loc_office)

        for g = 1 : mod.params["num_groups"]
            groups["group $g"] = Group("group $g")
        end
    end

    iface_atrium = Interface()
    il = InputLocation()
    push!(il.env_processes, Process("start_agents", start_agents ) )
    il.functions[Employee] = employee_process
    il.functions[Leader] = leader_process
    il.functions[Attacker] = attacker_process

    iface_atrium.input_locations["Atrium"] = il
    model.interfaces["Atrium"] = iface_atrium


    model.locations["Office"] = loc_office

    return model


end


# m = create_scenarioA_model()
# sim = Simulation(m)
#
# logstream = open("test.log", "w")
# jslog_init(sim, logstream)
#
# start(sim)
#
# run(sim, 12hours)
#
# jslog_end(sim)
