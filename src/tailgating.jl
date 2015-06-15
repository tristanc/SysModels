
#using SecSim
#include("shared-resources.jl")


type TailgateSignal <: Resource
  tailgater :: Agent
  challenged :: Bool
end

type Receptionist <: Resource
end

TailgateSignal(agent :: Agent) = TailgateSignal(agent, false)

function create_tailgating_model()

  #define locations
  local loc_outside :: Location
  local loc_atrium :: Location
  loc_foyer   = Location("Foyer")
  loc_entry   = Location("Hallway")
  loc_sec     = Location("Security Office")
  loc_reception = Location("Reception")

  #link locations
  link(loc_foyer, loc_entry)
  link(loc_sec, loc_foyer)
  link(loc_reception, loc_foyer)


  entry_door :: Door = Door(loc_foyer)
  distrib(entry_door, loc_foyer)

  local num_receptionists :: Integer
  local p_forget_card :: Float64
  local dist_reception_time :: Distribution
  local expected_arrival_time :: Float64

  local atrium_funcs :: Dict{Type, Function}
  local outside_funcs :: Dict{Type, Function}

  local num_guards :: Integer
  local p_guard_observes :: Float64

  function queue_for_badge(proc :: Process, agent :: Agent)

      model = get_model(proc)
      model.data["reception_count"] += 1

      start_time = now(proc)
      move(proc, agent, loc_foyer, loc_reception)
      hold(proc, 10seconds)
      success, claimed = @claim(proc, (loc_reception, Receptionist))

      hold(proc, rand(proc.simulation.model.params["dist_reception_time"]))
      res = flatten(claimed)[1]
      release(proc, loc_reception, res)

      move(proc, agent, loc_reception, loc_foyer)
      hold(proc, 10seconds)
      wait_time = now(proc) - start_time
      push!(model.data["reception_wait_times"], wait_time)

  end

  function through_entry(proc :: Process, agent :: Agent)
    #println("normal entry")
    access(proc, agent, entry_door)
    move(proc, agent, loc_foyer, loc_entry)

    f = find( res -> isa(res, TailgateSignal) && !res.challenged )
    success, claimed = @claim(proc, (loc_entry, f), 12.0seconds)
    if success
        #println("observed tailgating")

        @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
            "time" => now(proc.simulation),
            "type" => "event",
            "id" => string(object_id(agent)),
            "value" => "Observed tailgating."
        ))

        sig = flatten(claimed)[1]
        #choice = choose(agent, :ignore, :challenge)
        choices = Dict{Symbol, Vector{Float64}}(:ignore => [1.7, 1.1], :challenge => [1.3, 1.5])
        choice = choose(agent, choices)

        @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
            "time" => now(proc.simulation),
            "type" => "choice",
            "id" => string(object_id(agent)),
            "value" => string(choice)
        ))

        if choice == :ignore
            #println("ignore")
            #release resource so others can see
            release(proc, loc_entry, sig)
        else
        #    println("challenge")
            sig.challenged = true
            release(proc, loc_entry, sig)
            hold(proc, 15seconds)
        end

    end


    move(proc, agent, loc_entry, loc_atrium)
  end

  function through_entry_tailgate(proc :: Process, agent :: Agent)
    #println("tailgate")
    #tailgate through the door
    access(proc, agent, entry_door)
    move(proc, agent, loc_foyer, loc_entry)

    model = proc.simulation.model


    @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
        "time" => now(proc.simulation),
        "type" => "event",
        "id" => string(object_id(agent)),
        "value" => "Tailgated."
    ))

    @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
        "time" => now(proc.simulation),
        "type" => "change-attributes",
        "id" => string(object_id(agent)),
        "style" => Dict{Any,Any}( "fill" => "#f00"),
        "attr" => Dict{Any,Any}()
    ))

    @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
        "time" => now(proc.simulation),
        "type" => "inc-count",
        "var" => "tailgate"
    ))

    sig = TailgateSignal(agent)
    add(proc, sig, loc_entry)

    hold(proc, 10seconds)

    f = find( res -> isa(res, TailgateSignal) && res.tailgater == agent )
    success, claimed = @claim(proc, (loc_entry, f))


    if sig.challenged
        #println("got challenged")
        model.data["tailgate_challenged_employee"] += 1

        @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
            "time" => now(proc.simulation),
            "type" => "change-attributes",
            "id" => string(object_id(agent)),
            "style" => Dict{Any,Any}( "fill" => "yellow"),
            "attr" => Dict{Any,Any}()
        ))

        @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
            "time" => now(proc.simulation),
            "type" => "inc-count",
            "var" => "challenge"
        ))

        #go back and queue for reception
        access(proc, agent, entry_door)
        move(proc, agent, loc_entry, loc_foyer)
        hold(proc, 15seconds)
        queue_for_badge(proc, agent)
        access(proc, agent, entry_door)
        move(proc, agent, loc_foyer, loc_entry)
        hold(proc, 10seconds)
    else
        hold(proc, 5seconds)
        model.data["tailgate_success_employee"] += 1
    end

    #now remove our resource
    remove(proc, sig, loc_entry)

    #println("To Atrium")
    move(proc, agent, loc_entry, loc_atrium)
  end

  function in_atrium(proc :: Process, agent :: Agent)
      #wait all day
      hold(proc, 8hours)
  end



  function agent_process(proc :: Process, agent :: Agent)


    model = get_model(proc)

    move(proc, agent, loc_outside, loc_foyer)

    if rand() > p_forget_card
      #can access door
      through_entry(proc, agent)
    else
      #can't access door
      #queue at reception or tailgate

      @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
          "time" => now(proc.simulation),
          "type" => "event",
          "id" => string(object_id(agent)),
          "value" => "Forgot card."
      ))

      while true

        #how long is the queue? What is expected wait time?
        qlen = length(get_store(loc_reception).resources)
        qtime = (mean(dist_reception_time) / num_receptionists) * qlen

        lateness = time_of_day(now(proc) + qtime) - time_of_day(expected_arrival_time)
        tailgate_prod = 1.2
        if lateness > 0
            tailgate_prod = min(1.2, 1.2 + (lateness / 5minutes))
        end

        choices = Dict{Symbol, Vector{Float64}}(:reception => [1.1, 1.6], :tailgate => [tailgate_prod, 1.2])
        choice = choose(agent, choices)

        @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
            "time" => now(proc.simulation),
            "type" => "choice",
            "id" => string(object_id(agent)),
            "value" => string(choice)
        ))

        if choice == :reception
          #reception
          #get new badge
          @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
              "time" => now(proc.simulation),
              "type" => "change-attributes",
              "id" => string(object_id(agent)),
              "style" => Dict{Any,Any}( "fill" => "#0f0"),
              "attr" => Dict{Any,Any}()
          ))

          @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
              "time" => now(proc.simulation),
              "type" => "inc-count",
              "var" => "reception"
          ))

          queue_for_badge(proc,agent)
          through_entry(proc, agent)
          break
        else
          success, claimed = @claim(proc, (entry_door.signal_loc, entry_door.open_res), 180.0seconds)
          if success
            #tailgate
            release(proc, entry_door.loc, entry_door.open_res)
            model.data["tailgate_attempts_employee"] += 1
            #see if we are stopped by a guard
            if num_guards == 0 || rand() <= ((1-p_guard_observes) ^ num_guards)
                #made it through!
                through_entry_tailgate(proc,agent)
                break
            else
                #we are caught
                model.data["guard_stopped_employee"] += 1
                queue_for_badge(proc,agent)
                through_entry(proc, agent)
                break
            end

          else
            #println("failed tailgate")
            #decide again if we want to tailgate
            continue
          end
        end
      end
    end

    # call next model (if composed)
    # otherwise this calls in_office
    f = get_func(atrium_funcs, typeof(agent))
    f(proc, agent)

    move(proc, agent, loc_atrium, loc_entry)
    access(proc, agent, entry_door)
    move(proc, agent, loc_entry, loc_foyer)
    hold(proc, 15seconds)
    move(proc, agent, loc_foyer, loc_outside)


  end

  function launch_agent_process(proc :: Process, agent :: Agent)
      @claim(proc, (loc_outside, agent))
      agent_process(proc, agent)
  end


  function attacker_tailgate(proc :: Process, agent :: Attacker)
      #println("tailgate")
      #tailgate through the door

      model = get_model(proc)


      access(proc, agent, entry_door)
      move(proc, agent, loc_foyer, loc_entry)

      @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
          "time" => now(proc.simulation),
          "type" => "event",
          "id" => string(object_id(agent)),
          "value" => "Tailgated."
      ))

      @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
          "time" => now(proc.simulation),
          "type" => "change-attributes",
          "id" => string(object_id(agent)),
          "style" => Dict{Any,Any}( "fill" => "#f00"),
          "attr" => Dict{Any,Any}()
      ))

      @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
          "time" => now(proc.simulation),
          "type" => "inc-count",
          "var" => "tailgate"
      ))

      sig = TailgateSignal(agent)
      add(proc, sig, loc_entry)

      hold(proc, 10seconds)

      f = find( res -> isa(res, TailgateSignal) && res.tailgater == agent )
      success, claimed = @claim(proc, (loc_entry, f))

      if sig.challenged
          #println("got challenged")
          model.data["tailgate_challenged_attacker"] += 1

          @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
              "time" => now(proc.simulation),
              "type" => "change-attributes",
              "id" => string(object_id(agent)),
              "style" => Dict{Any,Any}( "fill" => "yellow"),
              "attr" => Dict{Any,Any}()
          ))

          @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
              "time" => now(proc.simulation),
              "type" => "inc-count",
              "var" => "challenge"
          ))

          #just go home

          remove(proc, sig, loc_entry)
      else
          hold(proc, 5seconds)
          #move to atrium
          move(proc, agent, loc_entry, loc_atrium)
          remove(proc, sig, loc_entry)

          #call next model
          model.data["tailgate_success_attacker"] += 1
          f = get_func(atrium_funcs, typeof(agent))
          f(proc, agent)

          #move back again

          move(proc, agent, loc_atrium, loc_entry)
      end

      access(proc, agent, entry_door)
      move(proc, agent, loc_entry, loc_foyer)

    end

  function attacker_process(proc :: Process, agent :: Attacker)
    #println("attacker starting")
    move(proc, agent, loc_outside, loc_foyer)

    model = get_model(proc)

    success, claimed = @claim(proc, (entry_door.signal_loc, entry_door.open_res), 5minutes)
    if success
      #tailgate
      release(proc, entry_door.loc, entry_door.open_res)
      model.data["tailgate_attempts_attacker"] += 1
      #see if we are stopped by a guard
      if num_guards == 0 || rand() <= ((1-p_guard_observes) ^ num_guards)
          #made it through!
          attacker_tailgate(proc,agent)
      else
          #we are caught, go home
          model.data["guard_stopped_attacker"] += 1
      end

    else
      #println("attacker failed tailgate")

    end

      hold(proc, 15seconds)
      move(proc, agent, loc_foyer, loc_outside)

  end

  function launch_attacker_process(proc :: Process, agent :: Attacker)
    @claim(proc, (loc_outside, agent))
    attacker_process(proc, agent)
  end

  function start_attackers(proc :: Process)
      #println("start_attackers")
      local sim :: Simulation = proc.simulation
      local model = sim.model

      d_start_time = Normal(model.params["expected_arrival_time"], 10minutes)

      for emp in model.data["attackers"]
          att_proc = Process("attacker", (p) -> launch_attacker_process(p, emp))
          add(proc, emp, loc_outside)
          start(proc, att_proc, rand(d_start_time))
      end
  end

  function start_agents(proc :: Process)

      local sim :: Simulation = proc.simulation
      local model = sim.model

      d_start_time = Normal(model.params["expected_arrival_time"], 10minutes)

      for emp in model.data["employees"]
          emp_proc = Process("employee", (p) -> launch_agent_process(p, emp) )
          add(proc, emp, loc_outside)
          start(proc, emp_proc, rand(d_start_time))
      end

      for emp in model.data["leaders"]
          emp_proc = Process("leader", (p) -> launch_agent_process(p, emp) )
          add(proc, emp, loc_outside)
          start(proc, emp_proc, rand(d_start_time))
      end

  end



  model = Model()

  model.setup = (mod :: Model) ->
    begin
        loc_outside = get_location(mod, "Outside")
        link(loc_outside, loc_foyer)

        loc_atrium = get_location(mod, "Atrium")
        link(loc_atrium, loc_entry)

        atrium_funcs  = get_funcs(mod, "Atrium")
        outside_funcs = get_funcs(mod, "Outside")

        num_receptionists = mod.params["num_receptionists"]
        dist_reception_time = mod.params["dist_reception_time"]
        expected_arrival_time = mod.params["expected_arrival_time"]
        p_forget_card = mod.params["p_forget_card"]
        num_guards = mod.params["num_guards"]
        p_guard_observes = mod.params["p_guard_observes"]

        for x = 1 : num_receptionists
            receptionist = Receptionist()
            distrib(receptionist, loc_reception)
        end

    end

  iface_outside = Interface()
  il = InputLocation()
  push!(il.env_processes, Process("start_employees", start_agents ) )
  il.functions[Agent] = agent_process
  iface_outside.input_locations["Outside"] = il
  model.interfaces["Outside"] = iface_outside



  iface_atrium = Interface()
  ol = OutputLocation()
  ol.functions[Agent] = in_atrium
  iface_atrium.output_locations["Atrium"] = ol
  model.interfaces["Atrium"] = iface_atrium

  push!(model.env_processes, Process("start_attackers", start_attackers))



  return model

end

# m = create_tailgating_model()
# sim = Simulation(m)
#
# logstream = open("test.log", "w")
# jslog_init(sim, logstream)
#
# start(sim)
# run(sim, 12hours)
#
# jslog_end(sim)
