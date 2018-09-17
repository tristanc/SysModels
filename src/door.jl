
mutable struct DoorOpen <: Resource
    close_time :: Float64
end

mutable struct Door <: Resource
    loc :: Location
    open_res :: DoorOpen
    is_open :: Bool
    signal_loc :: Location
end

Door(loc :: Location) = Door(loc, DoorOpen(0.0), false, Location("door-signal-location"))

function access(proc :: Process, agent :: Agent, door :: Door)

    success, claimed = @claim(proc, (door.loc, door))

    d_time = Distributions.Normal(0, .2seconds)

    if door.is_open

      door.open_res.close_time = now(proc) + 7seconds
      hold(proc, 1.2seconds + rand(d_time))

    else

      #wait a few seconds, the time to open the door and go through
      hold(proc, 2.0seconds + rand(d_time))
      #now launch the close process
      door.open_res.close_time = now(proc) + 7seconds
      doorproc = Process("door_close_process", (p) -> door_close_process(p, door))
      start(proc, doorproc)
    end

    release(proc, door.loc, door)
end

function door_close_process(proc :: Process, door :: Door)

    door.is_open = true
    add(proc, door.open_res, door.signal_loc)
    while true
      close_time = door.open_res.close_time
      if close_time > now(proc)
        wait_time = close_time - now(proc)

        hold(proc, wait_time)
      else
        break
      end

    end

    door.is_open = false
    success, claimed = @claim(proc, (door.signal_loc, door.open_res))
    remove(proc, door.open_res, door.signal_loc)

end
