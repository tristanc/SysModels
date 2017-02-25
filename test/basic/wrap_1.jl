# Wrap a model in a function


using SysModels
using Distributions

type Widget <: Resource
end

function create_model()

  locA = Location("A")
  locB = Location("B")

  link(locA, locB)

  function create_widgets(proc :: Process)

    # normal distribution
    norm_dist = Normal(5.0, 0.5)

    for i = 1:10
      #wait for random amount of seconds
      #drawn from norm_dist
      hold(proc, rand(norm_dist))

      #create widget
      w = Widget()

      #add widget to locA
      # Note: before simulation starts, use distrib to place resources.
      # During simulation, use add.  This causes the claims for resources
      # to be evaluated
      add(proc, w, locA)

      println("Created Widget")
    end

  end

  function move_widget(proc :: Process)

    while true
      #claim 2 widgets
      success, claimed = @claim(proc, (locA, Widget))

      widgets = flatten(claimed)

      println("Claimed $(length(widgets)) Widgets.")

      move(proc, widgets, locA, locB)
      release(proc, locB, widgets)
      println("Moved widgets.")

    end

  end



  p1 = Process("Widget Creator", create_widgets)
  p2 = Process("Widget Mover", move_widget)

  model = Model()

  push!(model.env_processes, p1)
  push!(model.env_processes, p2)

  return model

end

#create model
m = create_model()

sim = Simulation(m)
SysModels.start(sim)
SysModels.run(sim, 20seconds)
