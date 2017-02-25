
using SysModels

type Widget <: Resource
end

locA = Location("A")
locB = Location("B")

link(locA, locB)

w = Widget()
distrib(w, locA)

function move_widget(proc :: Process)
  #claim a Widget
  success, claimed = @claim(proc, (locA, Widget))

  widgets = flatten(claimed)

  move(proc, widgets, locA, locB)
  println("Widget Moved")
  release(proc, locB, widgets)
end

p = Process("Widget Mover", move_widget)

model = Model()

push!(model.env_processes, p)

sim = Simulation(model)

SysModels.start(sim)
SysModels.run(sim, 1.0seconds)
