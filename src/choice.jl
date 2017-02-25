

function simple_random_choice(agent :: Agent, choices :: Dict{Symbol, Vector{Float64}})
    #ks = collect(keys(choices))
    #return ks[rand(1: length(ks))]
    #return collect(keys(choices))[rand(1:length(choices))]
end

function choose_from_preferences(agent :: Agent, choices :: Dict{Symbol, Vector{Float64}})

    prefs = get_data(agent).data["preferences"]

    max = -1.0
    local best :: Symbol
    for (sym, vals) in choices
        score = 0.0
        for i = 1 : length(prefs)
                score += prefs[i] * vals[i]
        end
        if score > max
                best = sym
                max = score
        end
    end

    return best

end

function choose_stochastic(agent :: Agent, choices :: Dict{Symbol, Vector{Float64}})
    prefs = get_data(agent).data["preferences"]

    scores = Float64[]
    Symbols = Symbol[]
    total = 0

    for (sym, vals) in choices
        score = 0.0
        for i = 1 : length(prefs)
                score += prefs[i] * vals[i]
        end
        total += score
        push!(scores, score)
        push!(Symbols, sym)
    end

    #now normalise
    scores /= total

    r = rand()
    cur_total = 0
    for i = 1:length(Symbols)
        cur_total += scores[i]
        if r <= cur_total
            return Symbols[i]
        end
    end

end

# Make a choice between alternatives, according
# to the sim's choice function
function choose(agent :: Agent, choices :: Dict{Symbol, Vector{Float64}})
    #choice_func = agent.sim.choice_function
    #return simple_random_choice(agent, choices)
    return choose_from_preferences(agent, choices)
end
