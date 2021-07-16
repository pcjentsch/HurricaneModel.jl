# const default_gamma = 1/5
struct ModelParameters
    β::Float64
    γ::Float64
    I_0::Float64
    # τ::Int
end

struct DataChunk
    cases_list::Vector{Float64} #incident cases by day
    begin_date::Date #date corresponding to total cases
    jurisdiction_population::Float64
    recovered::Float64
end




function model_rhs(du,u,p,t)
    (;β,γ) = p
    du[1] = -β * u[1]*u[2] #S
    du[2] = β * u[1]*u[2] - γ*u[2] #I 
    du[3] = β * u[1]*u[2] #accumulate total cases to compute daily incidence
    #no need for R
end
function model(p, data_chunk)
    β,γ, I_0 = p
    l = length(data_chunk.cases_list) - 1

    p = ModelParameters(β/data_chunk.jurisdiction_population,γ,I_0)
    u0 = [
        data_chunk.jurisdiction_population -  (I_0 + data_chunk.recovered),
        I_0,
        0
    ]

    prob = ODEProblem(model_rhs, u0,(0.0,l),p)
    sol = solve(prob,Tsit5(); saveat = 1.0)
    return sol
end

function cost(sol,data)
    c = 0.0
    for i in 1:length(data) - 1
        c += ((sol.u[i+1][3] - sol.u[i][3]) - data[i])^2
    end
    return c
end
using BenchmarkTools
using BlackBoxOptim
function fit_submodel(data_chunk)
    data = data_chunk.cases_list
    l = Float64(length(data)) - 1
    x_0 = [2.0,0.5,100.0]

    function f(x,p)
        sol = model(x,p)
        return cost(sol,p.cases_list)
    end

    # @btime f($x_0,$data_chunk)

    prob = GalacticOptim.OptimizationProblem(f,x_0,data_chunk; lb = [0.0,0.0,0.0], ub = [5.0,1.0, 10_000.0])
    minimizer = solve(prob,BBO()).u
    display(minimizer)

    minimum_sol = model(minimizer, data_chunk)
    p = plot([minimum_sol[i][3] - minimum_sol[i-1][3] for i in 2:length(minimum_sol)])
    plot!(data_chunk.cases_list)
    display(p)
end

