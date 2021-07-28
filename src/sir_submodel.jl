
function model_rhs(u,p,t)
    β,γ = p
    return SLVector(
       S = -β * u.S*u.I, #S
       I = β * u.S*u.I - γ*u.I, #I 
       C = β * u.S*u.I#accumulate total cases to compute daily incidence
        #no need for R
    )
end

function sir_model(p, data_chunk; extend = 0.0)
    β,γ,I_0 = p
    l = length(data_chunk.new_cases) - 1
    params = (β/data_chunk.population,γ)
    recovered = data_chunk.total_cases[begin]
    u0 = SLVector(
        S = data_chunk.population - (I_0+ recovered + data_chunk.total_vaccinations[begin]), #S
        I = I_0, 
        C = 0.0  
     )
    prob = ODEProblem{false}(model_rhs, u0,(0.0,l + extend),params)
    sol = solve(prob,Tsit5(); saveat = 1.0)
    return sol.u
end

function cost(sol,data,x)
    β,γ,I_0 = x
    c = 0.0
    @inbounds @simd for i in 1:length(data) - 1
        c += ((sol[i+1][3] - sol[i][3]) - data[i])^2
    end
    # @inbounds @simd for i in 1:length(data)
    #     c += (sol[i][3] - data[i])^2
    # end
    return c + 1e3*(1/γ - 1/6)^2 #regularize on serial interval
end
function sir_submodel(data_chunk::LocationData; x_0 = [1.0,0.5,100.0])

    function f(x::Vector{T}) where T<:Real
        sol = sir_model(x,data_chunk)
        return cost(sol,data_chunk.new_cases,x)
    end
    res = bboptimize(f; SearchRange = [(0.05,10.0),(0.05,10.0),(0.0,10_000.0)],
    TraceMode = :silent, NumDimensions = 3,MaxFuncEvals = 30_000)
    # display(best_candidate(res))
    return best_candidate(res)#minx
end

function SIR_statistics(model)
    β, γ = model
    return [β/γ, 2/γ]
end


function sir_dist(x,y)
    eps = (0.1,0.1)
    transformed_x = SIR_statistics(x)
    transformed_y = SIR_statistics(y)
    # display((transformed_x,transformed_y))
    for (x_i,y_i,eps_i) in zip(transformed_x,transformed_y,eps)
        if !(abs(x_i - y_i)<eps_i)
            return false
        end
    end
    return true
end