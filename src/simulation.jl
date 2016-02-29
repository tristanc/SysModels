

type Process

	name :: ASCIIString
	scheduled :: Bool
	start_func :: Function
	task :: Task
	claimed_resources :: Vector{Resource}
	simulation

	function Process(name :: ASCIIString, start_func :: Function)
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
	name :: ASCIIString
	stores :: Dict{ASCIIString, Store}
	links :: Dict{Location, Bool}
	resources :: Vector{Resource}

	function Location(name :: ASCIIString)
			loc = new()
			loc.name = name
			loc.stores = Dict{ASCIIString, Store}()
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
	input_locations :: Dict{ASCIIString, InputLocation}
	output_locations :: Dict{ASCIIString, OutputLocation}

	function Interface()
		i = new()
		i.input_locations = Dict{ASCIIString, InputLocation}()
		i.output_locations = Dict{ASCIIString, OutputLocation}()
		return i
	end
end

type Model
	interfaces :: Dict{ASCIIString, Interface}
	interface_funcs :: Dict{ASCIIString, Dict{Type, Function}}

	setup:: Function

	env_processes :: Vector{Process}

	locations :: Dict{ASCIIString, Location}

	params :: Dict{ASCIIString, Any}
	data :: Dict{ASCIIString, Any}

	function Model()
		m = new()
		m.interfaces = Dict{ASCIIString, Interface}()
		m.env_processes = []
		m.locations = Dict{ASCIIString, Location}()
		m.interface_funcs = Dict{ASCIIString, Dict{Type, Function}}()
		m.params = Dict{ASCIIString, Any}()
		m.data = Dict{ASCIIString, Any}()
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
