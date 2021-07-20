function make_data_chunks(location_data,size,resolution)
    
   return map(i -> chunk_data(location_data,i,size),1:resolution:length(location_data)-size) 
end

function chunk_data(location_data, position, length)
    (; total_cases, new_cases, new_vaccinations,total_vaccinations, population, dates) = location_data
    return LocationData(
        total_cases[position:position+length],
        new_cases[position:position+length],
        new_vaccinations[position:position+length],
        total_vaccinations[position:position+length],
        dates[position:position+length],
        population,
    )
end

function fit_region((region_key,region_data,))
    region_data_chunks = make_data_chunks(region_data,60,4)    
    models = fit_submodel(region_data_chunks)
    return [(loc = region_key,date = chunk.dates[begin],stats = model) for (chunk,model) in zip(region_data_chunks,models)] 
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
    eps = (0.05,0.1)
    for (x_i,y_i,eps_i) in zip(x,y,eps)
        if !(abs(x_i - y_i)<eps_i)
            return false
        end
    end
    return true
end


function forecast(x::LocationData,aggregate_data,forecast_length, location_data_by_region)
    model = fit_submodel(x)
    display(SIR_statistics(model))
    begin_date = x.dates[begin]
    sufficiently_close_to_x(pt) = sufficiently_close(SIR_statistics(pt),SIR_statistics(model))
    close_pts = filter(:stats => sufficiently_close_to_x,aggregate_data) |>
            df -> filter(:date => <(begin_date - Day(length(x))),df) 
    
    map!(SIR_statistics,close_pts[!,:stats],close_pts[!,:stats])
    display(close_pts)
    timeseries = mapreduce(hcat,eachrow(close_pts)) do pt
        loc_data = location_data_by_region[pt[:loc]]
        index_of_date = findfirst(==(pt[:date]),loc_data.dates) 
        timeseries_from_date = loc_data.total_cases[index_of_date:min(end,index_of_date + forecast_length)]
        scale = x.total_cases[begin] / timeseries_from_date[begin]
        return  timeseries_from_date .* scale
    end
    
    # display(median_forecast)
    return close_pts, timeseries
end