


function jslog_init(sim, stream)
    if jsloglevel > LOG_OFF
        sim.log_stream = stream

        locs = Any[]
        links = Any[]
        for l in values(sim.model.locations)
            push!(locs,toJSON(l))

            for (dest, enabled) in l.links
                push!(links, Dict{Any,Any}(
                    "from" => string(object_id(l)),
                    "to" => string(object_id(dest)),
                    "enabled" => enabled
                ))
            end
        end


        write(sim.log_stream, " {\n")
        write(sim.log_stream, "\"locations\": ")
        JSON.print(sim.log_stream, locs)
        write(sim.log_stream, ",\n\"links\": ")
        JSON.print(sim.log_stream, links)
        write(sim.log_stream, ",\n\"log\": [\n")

    end
end

function jslog_end(sim)
    if jsloglevel > LOG_OFF
        time = now(sim)
        write(sim.log_stream, "{ \"type\":\"end-log\", \"time\": $time} ]\n}\n")
    end
end

function jslog(sim, obj)
    JSON.print(sim.log_stream, obj)
    write(sim.log_stream, ",\n")
end

macro jslog(level, sim, obj)

  if eval(level) > jsloglevel
      return nothing
  else
      return quote
          jslog($(esc(sim)), $(esc(obj)))
      end
  end
end


macro iflog(level, code)
    if eval(level) > jsloglevel
        return nothing
    else
        return quote
            $(esc(code))
        end
    end
end
