

ret = @parallel (combine) for i = 1 : 10

m1 = create_device_loss_model()
m2 = create_tailgating_model()
m3 = create_document_sharing_model()

temp_m = compose(m1, "Outside", m2, "Outside")

m = compose(m3, "Atrium", temp_m, "Atrium")

m.params["num_groups"] = 20
m.params["employees_per_group"] = 20
m.params["expected_arrival_time"] = 9hours

m.params["num_receptionists"] = 1
m.params["dist_reception_time"] = Normal(120, 20seconds)

m.params["num_guards"] = 1
m.params["p_guard_observes"] = .6


m.params["p_forget_card"] = .05


m.params["dist_prod"] = Beta(2,2)
m.params["dist_sec"] = Beta(2,2)

m.params["num_attackers"] = 5

m.params["p_public_transport"] = .5
m.params["p_lose_device"] = .001


#data from tailgating model
m.data["tailgate_attempts_employee"] = 0
m.data["tailgate_success_employee"] = 0
m.data["tailgate_challenged_employee"] = 0
m.data["tailgate_attempts_attacker"] = 0
m.data["tailgate_success_attacker"] = 0
m.data["tailgate_challenged_attacker"] = 0
m.data["reception_count"] = 0
m.data["reception_wait_times"] = Float64[]
m.data["guard_stopped_employee"] = 0
m.data["guard_stopped_attacker"] = 0

#data from doc-sharing model
m.data["to_global"] = 0
m.data["to_email"] = 0
m.data["to_media"] = 0
m.data["attacker_found_media"] = 0

#data from device-loss model
m.data["device_lost"] = 0
m.data["emails_lost"] = 0

create_agents(m)
sim = Simulation(m)

#logstream = open("test.log", "w")
#jslog_init(sim, logstream)

start(sim)

run(sim, 24hours)
#jslog_end(sim)


delete!(m.data, "leaders")
delete!(m.data, "attackers")
delete!(m.data, "employees")

data_to_vector(m)

end

#for (k,v) in m.data
#        println("$k: $v")
#end

#println(ret)

A = Array(Any, 1, length(data_names))
for i = 1 : length(data_names)
    A[1,i] = data_names[i]
end
A = vcat(A, ret)

writecsv("/tmp/output.csv", A)
