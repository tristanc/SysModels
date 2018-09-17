
using SysModels


struct Widget <: Resource
end

locA = Location("A")
locB = Location("B")

link(locA, locB)

function move_widget_A(proc :: Process)

  #wait for 12 seconds before doing anything

  SysModels.hold(proc, 12seconds)

  #claim a Widget
  success, claimed = @claim(proc, (locA, Widget))

  widgets = flatten(claimed)

  move(proc, widgets, locA, locB)
  println("Widget Moved")

  release(proc, locB, widgets)
end

function move_widget_B(proc :: Process)

  while true
    #claim a Widget, with a 5 second timeout

    success, claimed = @claim(proc, (locB, Widget), 5seconds)


    if success
      println("B claimed Widget.")

      widgets = flatten(claimed)
      move(proc, widgets, locB, locA)

      release(proc, locA, widgets)
      println("Moved widget back.")
    else
      println("No widget claimed")
    end


  end

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
