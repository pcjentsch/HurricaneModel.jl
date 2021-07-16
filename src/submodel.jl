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

using StaticArrays
function model_rhs(u,p,t)
    (;β,γ) = p
    
    return @SVector [
        -β * u[1]*u[2], #S
        β * u[1]*u[2] - γ*u[2], #I 
        β * u[1]*u[2]#accumulate total cases to compute daily incidence
        #no need for R
    ] 
end

function model(p, data_chunk; extend = 0.0)::Vector{SVector{3,Float64}}
    β,γ, I_0 = p
    l = length(data_chunk.cases_list) - 1

    params = ModelParameters(β/data_chunk.jurisdiction_population,γ,I_0)
    u0 = @SVector[
        data_chunk.jurisdiction_population -  (I_0 + data_chunk.recovered),
        I_0,
        0.0
    ]
    # model_rhs(u0,params,0)
    prob = ODEProblem{false}(model_rhs, u0,(0.0,l + extend),params)
    # prob = ODEProblem{true}(model_rhs!, u0,[0.0,l],params)
    sol = solve(prob,Tsit5(); saveat = 1.0)
    return sol.u
end

function cost(sol,data)
    c = 0.0
    @inbounds @simd for i in 1:length(data) - 1
        c += ((sol[i+1][3] - sol[i][3]) - data[i])^2
    end
    return c
end
function fit_submodel(data_chunk::DataChunk)
    data = data_chunk.cases_list
    l = Float64(length(data)) - 1
    x_0 = [2.0,0.5,100.0]

    function f(x::Vector{Float64})
        sol = model(x,data_chunk)
        return cost(sol,data_chunk.cases_list)
    end
    # f(x_0,data_chunk)
    # @btime $f($x_0,$data_chunk)

    res = bboptimize(f,; SearchRange = [(0.0,10.0),(0.0,10.0),(0.0,50_000.0)],TraceMode = :silent)
    # display(res)
    # minimizer = solve(prob,BBO()).u
    return best_candidate(res)
end

