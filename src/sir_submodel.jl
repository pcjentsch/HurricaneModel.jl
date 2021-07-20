# const default_gamma = 1/5


using StaticArrays
function model_rhs(u,p,t)
    β,γ = p
    return @SVector [
        -β * u[1]*u[2], #S
        β * u[1]*u[2] - γ*u[2], #I 
        β * u[1]*u[2]#accumulate total cases to compute daily incidence
        #no need for R
    ] 
end

function model(p, data_chunk; extend = 0.0)::(Vector{SVector{3,T}} where T)
    β,γ,I_0 = p
    l = length(data_chunk.new_cases) - 1
    # I_0 = typeof(β)(data_chunk.cases_list[begin])
    params = (β/data_chunk.population,γ)
    recovered = data_chunk.total_cases[begin]
    # display(data_chunk.total_vaccinations[begin])
    u0 = @SVector[
        data_chunk.population - (I_0+ recovered + data_chunk.total_vaccinations[begin]),
        I_0,
        0.0,
    ]

    # model_rhs(u0,params,0)
    prob = ODEProblem{false}(model_rhs, u0,(0.0,l + extend),params)
    # prob = ODEProblem{true}(model_rhs!, u0,[0.0,l],params)
    sol = solve(prob,Tsit5(); saveat = 1.0)

    # display([sol.u[i+1][4] - sol.u[i][4] for i in 1:length(sol.u)-1])
    return sol.u
end

function cost(sol,data)
    c = 0.0
    @inbounds @simd for i in 1:length(data) - 1
        c += ((sol[i+1][3] - sol[i][3]) - data[i])^2
    end
    # @inbounds @simd for i in 1:length(data)
    #     c += (sol[i][3] - data[i])^2
    # end
    return c
end
using NLopt
using ForwardDiff
function fit_submodel(data_chunk::LocationData; x_0 = [1.0,0.5,100.0])

    function f(x::Vector{T}) where T<:Real
        sol = model(x,data_chunk)
        return cost(sol,data_chunk.new_cases)
    end
    res = bboptimize(f; SearchRange = [(0.01,50.0),(0.01,50.0),(0.0,10_000.0)],
    TraceMode = :silent, NumDimensions = 3,MaxFuncEvals = 30_000)
    # display(best_candidate(res))
    return best_candidate(res)#minx
end
function fit_submodel(data_chunks::Vector{LocationData})
    models = Vector{Vector{Float64}}()
    for chunk in data_chunks
        model = fit_submodel(chunk)
        push!(models, model)
    end
    return models
end
