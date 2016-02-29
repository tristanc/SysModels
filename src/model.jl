



function get_location(model :: Model, loc :: ASCIIString)
	return model.locations[loc]
end

function get_funcs(model :: Model, name :: ASCIIString)
	funcs = model.interface_funcs[name]
	return funcs
end

function get_func(funcs :: Dict{Type, Function}, t :: Type)

	curtype = t
	while curtype != Any
		if haskey(funcs, curtype)
			return funcs[curtype]
		end
		curtype = super(curtype)
	end

	#error, func not found!

end

function get_model(proc :: Process)
	return proc.simulation.model
end

function compose(m1 :: Model, iface1 :: ASCIIString, m2 :: Model, iface2 :: ASCIIString)

	model = Model()

	model.setup = (mod :: Model) -> begin
		m1.setup(mod)
		m2.setup(mod)
	end

	#add interfaces
	merge!(model.interfaces, m1.interfaces, m2.interfaces)
	#remove iface1, iface2
	delete!(model.interfaces, iface1)
	delete!(model.interfaces, iface2)

	#combine env_processes
	append!(model.env_processes, m1.env_processes)
	append!(model.env_processes, m2.env_processes)

	#combine locations
	merge!(model.locations, m1.locations, m2.locations)

	merge!(model.interface_funcs, m1.interface_funcs, m2.interface_funcs)

	for (k,v) in m1.interfaces[iface1].input_locations
		#create a new location with this name
		model.locations[k] = Location(k)
		model.interface_funcs[k] = v.functions
	end

	for (k,v) in m2.interfaces[iface2].input_locations
		#create a new location with this name
		model.locations[k] = Location(k)
		model.interface_funcs[k] = v.functions
	end

	merge!(model.params, m1.params, m2.params)
	merge!(model.data, m1.data, m2.data)

	return model

end
