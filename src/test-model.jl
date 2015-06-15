
using SecSim
import SecSim.@claim

type Employee <: Agent
    data :: AgentData
    Employee() = new()
end

type Rabbit <: Resource
end



function create_test_model()

    #create locations
    local locA :: Location
    locB = Location("locB")
    locC = Location("locC")

    #link locations
    link(locB, locC)
    link(locC, locB)

    rabbit = Rabbit()

    #distrib(rabbit, locB)

    function employee_process(proc :: Process, employee :: Employee)

        @claim(proc, (locA, employee) )
        println("started")
        hold(proc, 10.0)

        move(proc, employee, locA, locB)

        #println(macroexpand(:(@claim(proc, (locB, employee) && (locB, rabbit)))))
        success, claimed = @claim(proc, (locB, rabbit), 20.0)
        if success
          println("got rabbit")
        else
          println("failed to get rabbit")
        end

        move(proc, employee, locB, locC)
        hold(proc, 10.0)
        move(proc, employee, locC, locB)

        if success
          release(proc, locB, rabbit)
          println("released rabbit")
        end

        move(proc, employee, locB, locA)
        hold(proc, 10.0)

        println("done")

    end

    function start_employees(proc :: Process)

        local sim :: Simulation = proc.simulation

        println("se")
        for i = 1 : 10
            emp = Employee()
            emp_proc = Process("employee", (p) -> employee_process(p, emp) )
            distrib(emp, locA)
            start(proc, emp_proc)
        end
        println("se end")

    end

    model = Model()

    model.setup = () -> {
        locA = get_location(model, "locA")
        link(locA, locB)
        link(locB, locA)
        }

    il = InputLocation()
    push!(il.env_processes, Process("start_employees", start_employees ) )
    il.functions[Employee] = employee_process

    iface = Interface()
    iface.input_locations["locA"] = il

    model.interfaces["iface1"] = iface

    return model

end


m = create_test_model()
sim = Simulation(m)

run(sim, 1000.0)
