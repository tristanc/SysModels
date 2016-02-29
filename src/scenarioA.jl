
using SecSim


abstract Information <: Resource


type Computer <: Resource
    contents :: Location
    function Computer(name :: ASCIIString)
        c = new()
        c.contents = Location(name)
        return c
    end
end

function contents(comp :: Computer)
    return comp.contents
end

type DVD <: Resource
    contents :: Location
    function DVD(name :: ASCIIString)
        dvd = new()
        dvd.contents = Location(name)
        return dvd
    end
end

function contents(dvd :: DVD)
    return dvd.contents
end

type Document <: Information
    sent_time
    received_time
    classification
end



function create_scenarioA_model()

    const NUM_COMPUTERS = 20

    loc_group_share = Location("Group Share")
    loc_global_share = Location("Global Share")

    local loc_atrium :: Location
    loc_office = Location("Office")

    for i = 1 : NUM_COMPUTERS
        comp = Computer("Computer $i")
        distrib(comp, loc_office)

        link(contents(comp), loc_group_share)
        link(loc_groupshare, contents(comp))

        link(contents(comp), loc_global_share)
        link(loc_global_share, contents(comp))
    end


    function leader_process(sim :: Simulation, proc :: Process, leader :: Leader)
        @claim(proc, (loc_office, leader))

        #leader generates documents that must be sent to employees
        #different methods of distribution.

        release(sim, loc_office, leader)
    end


    function employee_process(sim :: Simulation, proc :: Process, employee :: Employee)
        @claim(proc, (loc_office, employee))

        local success :: Bool
        local claimed :: Dict{Location, Vector{Resource}}

        if can_access(loc_group_share)
            success, claimed = @claim(proc, (loc_office, DVD) || (loc_group_share, Document) ||
                (loc_global_share, Document))
        else
            success, claimed = @claim(proc, (loc_office, DVD) || (loc_global_share, Document))
        end



        release(sim, loc_office, employee)
    end


end
