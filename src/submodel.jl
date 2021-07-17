# const default_gamma = 1/5

struct DataChunk
    cases_list::Vector{Float64} #incident cases by day
    begin_date::Date #date corresponding to total cases
    jurisdiction_population::Float64
    recovered::Float64
end

using StaticArrays
function model_rhs(u,p,t)
    β,γ,σ = p
    
    return @SVector [
        -β * u[1]*u[3], #S
        β * u[1]*u[3] - σ*u[2], #E 
        σ*u[2] - γ*u[3], #I 
        β * u[1]*u[3]#accumulate total cases to compute daily incidence
        #no need for R
    ] 
end

function model(p, data_chunk; extend = 0.0)::(Vector{SVector{4,T}} where T)
    β,γ,σ, E_0,I_0 = p
    l = length(data_chunk.cases_list) - 1
    I_0 = typeof(β)(data_chunk.cases_list[begin])
    # display(data_chunk.cases_list)
    params = (β/data_chunk.jurisdiction_population,γ,σ)
    # display(data_chunk.jurisdiction_population)
    # display(data_chunk.recovered)
    # display(I_0)

    u0 = @SVector[
        data_chunk.jurisdiction_population -   (3*I_0+ data_chunk.recovered),
        E_0,
        I_0,
        0.0
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
        c += ((sol[i+1][4] - sol[i][4]) - data[i])^2
    end
    return c
end
using NLopt
using ForwardDiff
function fit_submodel(data_chunk::DataChunk)
    data = data_chunk.cases_list
    l = Float64(length(data)) - 1
    x_0 = [2.5,2.5,2.5,1000]

    function f(x::Vector{T}) where T<:Real
        sol = model(x,data_chunk)
        return cost(sol,data_chunk.cases_list)
    end
    function f_w_grad(x::Vector{T},grad::Vector) where T<:Real
        if length(grad)>0
            ForwardDiff.gradient!(grad,f,x)
        end
        return f(x)
    end
    
    # f(x_0,data_chunk)
    # @btime $f($x_0,$data_chunk)
    # betweenness centrality
    # f(x_0)
    res = bboptimize(f; SearchRange = [(0.0,10.0),(0.0,10.0),(0.0,10.0),(0.0,10_000.0),(0.0,10_000.0)],
    TraceMode = :silent, NumDimensions = 5,MaxFuncEvals = 15_000)
    # display(best_candidate(res))
    # minimizer = solve(prob,BBO()).u
    
    # grad = zeros(2)
    # f_w_grad(x_0,grad)
    
    # opt = Opt(:LD_LBFGS, 2)
    # opt.lower_bounds = [0.0,0.0]
    # opt.upper_bounds = [100.0,10_000.0]
    # opt.xtol_rel = 1e-4

    # opt.min_objective = f_w_grad

    # (minf,minx,ret) = NLopt.optimize(opt, x_0)
    # numevals = opt.numevals # the number of function evaluations
    # println("got $minf at $minx after $numevals iterations (returned $ret)")

    return best_candidate(res)#minx
end

