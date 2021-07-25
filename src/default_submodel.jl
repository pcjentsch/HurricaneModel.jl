function default_submodel(data_chunk::LocationData)
    chunk_size = length(data_chunk)
    @assert iseven(chunk_size)
    midpoint = div(chunk_size,2)
    total_cases = data_chunk.total_cases
    g_i_2 = (total_cases[end] - total_cases[midpoint]) / total_cases[midpoint]
    g_i_1 = (total_cases[midpoint] - total_cases[begin]) /total_cases[begin]
    return [g_i_2, g_i_2 - g_i_1]
end

function default_dist(x,y)
    eps = (0.02,0.02)
    for (x_i,y_i,eps_i) in zip(x,y,eps)
        if !(abs(x_i - y_i)<eps_i)
            return false
        end

    # display((x,y))
    end
    return true
end