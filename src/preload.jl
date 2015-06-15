using SecSim
using Distributions

include("shared-resources.jl")
include("device-loss.jl")
include("tailgating.jl")
include("document-sharing.jl")


data_names = ["reception_mean", "reception_total", "tailgate_attempts_employee",
"tailgate_success_employee", "tailgate_challenged_employee","tailgate_attempts_attacker",
"tailgate_success_attacker", "tailgate_challenged_attacker", "reception_count",
"guard_stopped_employee", "guard_stopped_attacker",
"to_global", "to_email", "to_media", "attacker_found_media", "device_lost", "emails_lost"]




function data_to_vector(m :: Model)
    A = zeros(Float64, 1, length(data_names))
    for i = 3:length(data_names)
        A[1,i] = m.data[data_names[i]]
    end
    A[1,1] = mean(m.data["reception_wait_times"])
    A[1,2] = sum(m.data["reception_wait_times"])

    return A
end


function combine(a :: Array{Float64,2}, b :: Array{Float64,2})
    return vcat(a,b)
end
