
function create_device_loss_model()

    local commute_time = 30minutes

    #internal locations
    local loc_home = Location("home")
    local loc_public_transport = Location("public-transport")
    local loc_car = Location("car")

    #interface location
    local loc_outside :: Location

    link(loc_home, loc_public_transport)
    link(loc_home, loc_car)

    local outside_funcs :: Dict{Type, Function}

    function at_work(proc :: Process, agent :: Agent)
        hold(proc, 8hours)
    end

    function agent_process(proc :: Process, agent :: Agent)

        model = get_model(proc)
        agent_data = get_data(agent)


        #move agent from home to transport
        if agent_data.data["use_public_transport"]
            move(proc, agent, loc_home, loc_public_transport)
            hold(proc, commute_time)
            #check to see if device is lost here
            # if rand() < model.params["p_lose_device"]
            #     #println("device lost")
            #     model.data["device_lost"] += 1
            #     #how many emails did we lose?
            #     model.data["emails_lost"] += length(get_store(agent_data.data["email"]).resources)
            # end


            move(proc, agent, loc_public_transport, loc_outside)
        else
            move(proc, agent, loc_home, loc_car)
            hold(proc, commute_time)
            move(proc, agent, loc_car, loc_outside)
        end


        #at work...
        f = get_func(outside_funcs, typeof(agent))
        f(proc, agent)

        #finished work, go back to home
        if agent_data.data["use_public_transport"]

            move(proc, agent, loc_outside, loc_public_transport)
            hold(proc, commute_time)
            #check to see if device is lost here
            if rand() < model.params["p_lose_device"]
                #println("device lost")
                model.data["device_lost"] += 1

                #how many emails did we lose?
                model.data["emails_lost"] += length(get_store(agent_data.data["email"]).resources)
            end
            move(proc, agent, loc_public_transport, loc_home)
        else
            move(proc, agent, loc_outside, loc_car)
            hold(proc, commute_time)
            move(proc, agent, loc_car, loc_home)
        end


    end

    function launch_agent_process(proc :: Process, agent :: Agent)
        @claim(proc, (loc_home, agent))
        agent_process(proc, agent)
    end

    function start_agents(proc :: Process)

        local sim :: Simulation = proc.simulation
        local model = sim.model

        d_start_time = Normal(model.params["expected_arrival_time"], 10minutes)

        for emp in model.data["employees"]
            emp_proc = Process("employee", (p) -> launch_agent_process(p, emp) )
            add(proc, emp, loc_home)
            start(proc, emp_proc, rand(d_start_time) - commute_time)
        end

        for emp in model.data["leaders"]
            emp_proc = Process("leader", (p) -> launch_agent_process(p, emp) )
            add(proc, emp, loc_home)
            start(proc, emp_proc, rand(d_start_time) - commute_time)
        end

    end

    model = Model()

    model.setup = (mod :: Model) -> begin
        loc_outside  = get_location(mod, "Outside")
        link(loc_public_transport, loc_outside)
        link(loc_car, loc_outside)

        outside_funcs = get_funcs(mod, "Outside")
    end

    iface_outside = Interface()
    ol = OutputLocation()
    ol.functions[Agent] = at_work
    iface_outside.output_locations["Outside"] = ol
    model.interfaces["Outside"] = iface_outside

    model.locations["Home"] = loc_home
    model.locations["Public Transport"] = loc_public_transport
    model.locations["Car"] = loc_car

    push!(model.env_processes, Process("start_agents", start_agents))

    return model


end
