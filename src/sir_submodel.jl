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
    l = length(data_chunk.cases_list) - 1
    # I_0 = typeof(β)(data_chunk.cases_list[begin])
    # display(data_chunk.cases_list)
    params = (β/data_chunk.jurisdiction_population,γ)
    # display(data_chunk.jurisdiction_population)
    # display(data_chunk.recovered)
    # display(I_0)

    u0 = @SVector[
        data_chunk.jurisdiction_population -   (I_0+ data_chunk.recovered),
        I_0,
        data_chunk.recovered
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
    # @inbounds @simd for i in 1:length(data) - 1
    #     c += ((sol[i+1][4] - sol[i][4]) - data[i])^2
    # end
    @inbounds @simd for i in 1:length(data)
        c += (sol[i][3] - data[i])^2
    end
    return c
end
using NLopt
using ForwardDiff
function fit_submodel(data_chunk::DataChunk; x_0 = [1.0,0.5,100.0])
    data = data_chunk.cases_list
    l = Float64(length(data)) - 1

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
    f(x_0)
    # display(x_0)
    # res = bboptimize(f,x_0; SearchRange = [(0.0,10.0),(0.0,10.0),(0.0,10_000.0)],
    # TraceMode = :silent, NumDimensions = 3,MaxFuncEvals = 20_000)
    # display(best_candidate(res))
    # minimizer = solve(prob,BBO()).u
    
    grad = zeros(3)
    f_w_grad(x_0,grad)
    
    opt = Opt(:LD_LBFGS, 3)
    opt.lower_bounds = [0.0,0.0,0.0]
    opt.upper_bounds = [10.0,10.0,10_000.0]
    opt.xtol_rel = 1e-4

    opt.min_objective = f_w_grad

    (minf,minx,ret) = NLopt.optimize(opt, x_0)
    numevals = opt.numevals # the number of function evaluations
    # println("got $minf at $minx after $numevals iterations (returned $ret)")

    return minx #best_candidate(res)#
end
function fit_submodel(data_chunks::Vector{DataChunk})
    
    x_0 = [2.5,2.5,1000.0]
    models = Vector{typeof(x_0)}()
    for chunk in data_chunks
        model = fit_submodel(chunk;x_0)
        push!(models, model)
        x_0 = model
    end
    return models
end
