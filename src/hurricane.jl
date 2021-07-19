
struct DataChunk
    cases_list::Vector{Float64} #incident cases by day
    begin_date::Date #date corresponding to total cases
    jurisdiction_population::Float64
    recovered::Float64
end
function make_data_chunks(location_data,size,resolution)
    (; cases, population, dates) = location_data
    daily_case_incidence = diff(cases)

    return map(50:resolution:length(cases)-size-1) do i
        DataChunk(
            cases[i:i+size],
            dates[i],
            population,
            cases[i-10] #guess
        )
    end
end

function fit_region((region_key,region_data,))
    region_data_chunks = make_data_chunks(region_data,30,7)    
    models = fit_submodel(region_data_chunks)
    return [(loc = region_key,date = chunk.begin_date,stats = SIR_statistics(model)) for (chunk,model) in zip(region_data_chunks,models)] 
end

function SIR_statistics(model)
    β, γ = model
    return [β/γ, 1/γ]
end

function aggregate(location_data_by_region)
    # if "cache.dat"
    regions = collect(pairs(location_data_by_region))
    df = DataFrame()#(loc = String[], date = Date[], stats = Any[])
    data_points = ThreadsX.map(fit_region, regions) |> l -> reduce(vcat,l)
    for row in data_points
        push!(df,row)
    end
    return df
end


function sufficiently_close(x,y)
    eps = (0.2,0.2)
    for (x_i,y_i,eps_i) in zip(x,y,eps)
        if !(abs(x_i - y_i)<eps_i)
            return false
        end
    end
    return true
end


function forecast(x::DataChunk,aggregate_data,forecast_length, location_data_by_region)
    model = fit_submodel(x)
    sufficiently_close_to_x(pt) = sufficiently_close(pt,SIR_statistics(model))
    display(SIR_statistics(model))
    close_pts = filter(:stats => sufficiently_close_to_x,aggregate_data) |>
            df -> filter(:date => <(x.begin_date - Day(length(x.cases_list))),df) 
    
    display(close_pts)

    timeseries = mapreduce(hcat,eachrow(close_pts)) do pt
        loc_data = location_data_by_region[pt[:loc]]
        index_of_date = findfirst(==(pt[:date]),loc_data.dates) 
        timeseries_from_date = loc_data.cases[index_of_date:min(end,index_of_date + forecast_length)]
        scale = x.cases_list[begin] / timeseries_from_date[begin]
        return timeseries_from_date .* scale
    end
    
    # display(timeseries)

    # display(median_forecast)
    return timeseries
end