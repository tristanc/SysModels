
using SysModels


type Widget <: Resource
end

locA = Location("A")
locB = Location("B")
locC = Location("C")

link(locA, locB)
link(locA, locC)

function move_widget_A(proc :: Process)

  #claim a Widget
  success, claimed = @claim(proc, (locA, Widget))

  widgets = flatten(claimed)

  rand_loc = locB
  if rand() < .5
    rand_loc = locC
  end

  move(proc, widgets, locA, rand_loc)
  println("Widget Moved to $(rand_loc.name)")

  release(proc, rand_loc, widgets)
end

function move_widget_B(proc :: Process)

    #claim a Widget from location B or loc C
    success, claimed = @claim(proc, ((locB, Widget) || (locC, Widget)))

    loc = locB

    # The @claim macro returns the resources claimed and the locations where
    # they were claimed.
    # The variable claimed is a dict of Store => Resource[]

    # Check if the widget was claimed from locC
    if haskey(claimed, get_store(locC))
      loc = locC
    end

    println("B claimed Widget from $(loc.name)")


end

w = Widget()
distrib(w, locA)

p1 = Process("Widget Mover A", move_widget_A)
p2 = Process("Widget Mover B", move_widget_B)

model = Model()

push!(model.env_processes, p1)
push!(model.env_processes, p2)

sim = Simulation(model)

SysModels.start(sim)
SysModels.run(sim, 20seconds)
