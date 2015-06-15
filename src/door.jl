
type DoorOpen <: Resource
    close_time :: Float64
end

type Door <: Resource
    loc :: Location
    open_res :: DoorOpen
    is_open :: Bool
    signal_loc :: Location
end

Door(loc :: Location) = Door(loc, DoorOpen(0.0), false, Location("door-signal-location"))

function access(proc :: Process, agent :: Agent, door :: Door)
    
    success, claimed = @claim(proc, (door.loc, door))

    if door.is_open

      door.open_res.close_time = now(proc) + 20seconds
      hold(proc, 5.0seconds)

    else

      #wait a few seconds, the time to open the door and go through
      hold(proc, 15.0seconds)
      #now launch the close process
      door.open_res.close_time = now(proc) + 10seconds
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
