

type Process

	name :: String
	scheduled :: Bool
	start_func :: Function
	task :: Task
	claimed_resources :: Vector{Resource}
	simulation

	function Process(name :: String, start_func :: Function)
			p = new()
			p.name = name
			p.scheduled = false
			p.start_func = start_func
			p.claimed_resources = Resource[]
			#p.task = Task( () -> start_func(p) )
			return p
	end

end



type Store
	resources :: Vector{Resource}
	#get_queue :: Vector{ClaimTree}
	get_queue :: Vector{Any}
	#taken :: Dict{Process, Vector{Resource}}

	function Store()
		s = new()
		s.resources = Resource[]
		s.get_queue = []
		#s.taken = Dict{Process, Vector{Resource}}()
		return s
	end
end

#Base.show(io :: IO, s :: Store) = print(io, "Store")

type Location
	name :: String
	stores :: Dict{String, Store}
	links :: Dict{Location, Bool}
	resources :: Vector{Resource}

	function Location(name :: String)
			loc = new()
			loc.name = name
			loc.stores = Dict{String, Store}()
			s = Store()
			loc.stores["default"] = s
			loc.resources = Resource[]
			loc.links = Dict{Location, Bool}()
			return loc
	end
end


type InputLocation
	functions :: Dict{Type, Function}
	env_processes :: Vector{Process}

	function InputLocation()
		il = new()
		il.functions = Dict{Type, Function}()
		il.env_processes = []
		return il
	end
end

type OutputLocation
	functions :: Dict{Type, Function}

	function OutputLocation()
		ol = new()
		ol.functions = Dict{Type, Function}()
		return ol
	end
end

type Interface
	input_locations :: Dict{String, InputLocation}
	output_locations :: Dict{String, OutputLocation}

	function Interface()
		i = new()
		i.input_locations = Dict{String, InputLocation}()
		i.output_locations = Dict{String, OutputLocation}()
		return i
	end
end

type Model
	interfaces :: Dict{String, Interface}
	interface_funcs :: Dict{String, Dict{Type, Function}}

	setup:: Function

	env_processes :: Vector{Process}

	locations :: Dict{String, Location}

	params :: Dict{String, Any}
	data :: Dict{String, Any}

	function Model()
		m = new()
		m.interfaces = Dict{String, Interface}()
		m.env_processes = []
		m.locations = Dict{String, Location}()
		m.interface_funcs = Dict{String, Dict{Type, Function}}()
		m.params = Dict{String, Any}()
		m.data = Dict{String, Any}()
		m.setup = (mod :: Model) -> begin end
		return m
	end

end

type Simulation
	time :: Float64
	process_queue :: PriorityQueue{Process, Float64}
	#process_queue :: PriorityQueue
	model :: Model
	log_stream :: IOStream

	function Simulation(model :: Model)
		sim = new()
		sim.time = 0.0
		sim.model = model
		sim.process_queue = PriorityQueue{Process, Float64, Order.ForwardOrdering}()
		#sim.process_queue = PriorityQueue()

		for iface in values(model.interfaces)
			for (key,oloc) in iface.output_locations
				model.locations[key] = Location(key)
				model.interface_funcs[key] = oloc.functions
			end
			for (key,iloc) in iface.input_locations
				model.locations[key] = Location(key)
				model.interface_funcs[key] = iloc.functions
			end
		end

		model.setup(model)

		return sim
	end

end


function start(sim :: Simulation)
	local model = sim.model

	for p in model.env_processes
		start(sim,p)
	end

	for iface in values(model.interfaces)
		for iloc in values(iface.input_locations)
			for p in iloc.env_processes
				start(sim, p)
			end
		end
	end
end


function run(sim :: Simulation, until :: Float64)

	pq = sim.process_queue

	while sim.time <= until && length(pq) > 0

		proc, priority = peek(pq)
		if !proc.scheduled
			dequeue!(pq)

			@jslog(LOG_MIN, sim, Dict{Any,Any}(
				"time" => now(sim),
				"type" => "remove-proc",
				"id" => object_id(proc)
			))

			continue
		end
		proc_time = pq[proc]
		if proc_time <= until
			dequeue!(pq)
			sim.time = proc_time
			proc.scheduled = false

			consume(proc.task)

		else
			break
		end
	end

	if sim.time <= until
		sim.time = until
	end

	#println("done")
end

function now(sim :: Simulation)
	return sim.time
end

function now(proc :: Process)
	return proc.simulation.time
end

function time_of_day(time :: Float64)
	return time % 1days
end
