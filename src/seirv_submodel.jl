
function seirv_model_rhs(u,p,t)
    β,γ,σ,ν = p
   
    SLVector(
        S = -β * u.S * u.I  - ν * u.S, #
        E = β * u.S * u.I - σ*u.E, #
        I = σ * u.E - γ * u.I, #
        V = ν * u.S, #
        C = β * u.S * u.I #
    )   #no need for R
end

function seirv_model(p, data_chunk; extend = 0.0)
    β,γ,σ,ν,I_0 = p
    l = length(data_chunk.new_cases) - 1
    params = (β/data_chunk.population,γ,σ, ν)
    recovered = data_chunk.total_cases[begin]
    u0 = SLVector(
        S = data_chunk.population - (2*I_0+ recovered + data_chunk.total_vaccinations[begin]),
        E = I_0,
        I = I_0,
        V = data_chunk.total_vaccinations[begin],
        C = data_chunk.total_cases[begin],
    )
    prob = ODEProblem{false}(seirv_model_rhs, u0,(0.0,l + extend),params)
    sol = solve(prob,Tsit5(); saveat = 1.0)
    return sol
end

function seirv_cost(sol,data,p)
    if sol.retcode == :Success
        β,γ,σ,ν,I_0 = p
        c = 0.0
        new_cases = data.new_cases
        total_vaccinations = data.total_vaccinations

        @inbounds for i in 1:length(new_cases) - 1
            c += ((sol[i+1][5] - sol[i][5]) - new_cases[i])^2
        end

        @inbounds @simd for i in 1:length(new_cases)
            c += 1e-6 * (sol[i][4] - total_vaccinations[i])^2
        end
        return c + 1e4*(1/γ - 1/6)^2 #regularize on serial interval
    else
        return Inf
    end
end
function seirv_submodel(data_chunk::LocationData;)

    function f(x::Vector{T}) where T<:Real
        sol = seirv_model(x,data_chunk)
        return seirv_cost(sol,data_chunk,x)
    end
    res = bboptimize(f; SearchRange = [(0.05,10.0),(0.05,10.0),(0.05,10.0),(0.00,10.0),(1.0,10_000.0)],
    TraceMode = :silent, NumDimensions = 3,MaxFuncEvals = 100_000)
    display(SEIRV_statistics(best_candidate(res)))
    return best_candidate(res)#minx
end

function SEIRV_statistics(model)
    β,γ,σ,ν,I_0 = model

    return [β/γ, 1/σ + 2/γ, ν]
end


function seirv_dist(x,y)
    eps = (0.15,0.15,0.002)
    transformed_x = SEIRV_statistics(x)
    transformed_y = SEIRV_statistics(y)
    for (x_i,y_i,eps_i) in zip(transformed_x,transformed_y,eps)
        if !(abs(x_i - y_i)<eps_i)
            return false
        end
    end
    return true
end