

function start(old_proc :: Process, new_proc :: Process, delay :: Float64 = 0.0)
  local sim :: Simulation = old_proc.simulation
  start(sim, new_proc, delay)
end

function wrap_task(sim, :: Simulation, task :: Task)
    println("waiting")
    wait(task)
    #yieldto(sim.task)
end

function start(sim :: Simulation, proc :: Process, delay :: Float64 = 0.0)
    proc.task = Task( () -> begin

                proc.start_func(proc)
                @jslog(LOG_MAX, sim, Dict{Any,Any}(
                    "time" => now(sim),
                    "type" => "remove-proc",
                    "id" => string(objectid(proc))
                ))
                
        end
    )

    proc.simulation = sim
    sim.process_queue[proc] = sim.time + delay
    proc.scheduled = true

    #schedule( Task( () -> wrap_task(sim, proc.task) ) )
    #yield()

    @jslog(LOG_MAX, sim, Dict{Any,Any}(
        "time" => now(sim),
        "type" => "add-proc",
        "id" => string(objectid(proc)),
        "name" => proc.name,
        "state" => "starting"
    ))

end

function terminated(proc :: Process)
    return istaskdone(proc.task)
end

function scheduled_time(proc :: Process)
    return proc.simulation.process_queue[proc]
end

function scheduled(proc :: Process)
    return proc.scheduled
end

function hold(proc :: Process, delay :: Float64)

    local sim :: Simulation = proc.simulation
    sim.process_queue[proc] = sim.time + delay
    proc.scheduled = true

    @jslog(LOG_MAX, sim, Dict{Any,Any}(
        "time" => now(sim),
        "type" => "update-proc",
        "id" => string(objectid(proc)),
        "state" => "holding"
    ))


    yieldto(proc.simulation.task)

    #produce(true)
end

function sleep(proc :: Process)
    proc.scheduled = false

    @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
        "time" => now(proc.simulation),
        "type" => "update-proc",
        "id" => string(objectid(proc)),
        "state" => "sleeping"
    ))


    yieldto(proc.simulation.task)

    #produce(true)
end

function wake(proc :: Process)
    local sim :: Simulation = proc.simulation
    proc.scheduled = true
    sim.process_queue[proc] = now(sim)

    @jslog(LOG_MAX, sim, Dict{Any,Any}(
        "time" => now(sim),
        "type" => "update-proc",
        "id" => string(objectid(proc)),
        "state" => "waking"
    ))

end

function cancel(proc :: Process)
    proc.scheduled = false

    @jslog(LOG_MAX, proc.simulation, Dict{Any,Any}(
        "time" => now(proc.simulation),
        "type" => "update-proc",
        "id" => string(objectid(proc)),
        "state" => "cancelled"
    ))

end
