struct HurricaneModel{F,G,T}
    submodel::F
    clustering_function::G
    loc_data::Vector{LocationData}
    fit_data::T
    chunk_length::Int
    spacing::Int
    function HurricaneModel(submodel::F,clustering_function::G,loc_data,length,spacing; cache = "cache.dat") where {F<:Function,G<:Function}
        data_chunks = mapreduce(x -> make_data_chunks(x, length,spacing),vcat,loc_data)

        row_from_chunk(chunk) = (loc = chunk.name,date = chunk.dates[begin],stats = submodel(chunk))

        if !ispath(cache)  
            df = ThreadsX.map(row_from_chunk,  data_chunks) |> DataFrame 
            serialize(cache,df)
        else
            df = deserialize(cache)
        end
        return new{F,G,typeof(df)}(submodel,clustering_function,loc_data,df,length,spacing)
    end
end
using UnPack
function forecast(x::LocationData,model::HurricaneModel,forecast_length)
    @unpack loc_data, clustering_function, submodel,fit_data = model

    source = submodel(x)
    last_date = end_date(loc_data[begin]);
    begin_date = x.dates[begin] - Day(length(x)) 
    # display((begin_date + Day(forecast_length),last_date))
    filter_from_date = begin_date + Day(forecast_length) > last_date ?
        begin_date -  ((begin_date + Day(forecast_length)) - last_date) : begin_date
    # display(filter_from_date)
    sufficiently_close_to_x(pt) = clustering_function(pt,source)
    close_pts = filter(:stats => sufficiently_close_to_x,fit_data) |>
            df -> filter(:date => <(filter_from_date),df) 
    
    display(close_pts)
    if !isempty(close_pts)
        timeseries = mapreduce(hcat,eachrow(close_pts)) do pt
            loc_ind = findfirst(p -> p.name == pt[:loc],loc_data)
            data = loc_data[loc_ind]
            index_of_date = findfirst(==(pt[:date]),data.dates) 
            timeseries_from_date = data.total_cases[index_of_date:min(end,index_of_date + forecast_length)]
            scale = x.total_cases[begin] / timeseries_from_date[begin]
            return  timeseries_from_date .* scale
        end
        return timeseries
    else
        return nothing
    end

    # display(median_forecast)
end

function forecast_from_date(data_to_forecast,hm,from_date)
    test_date = from_date - Day(hm.chunk_length)
    test_date_index = findfirst(==(test_date),data_to_forecast.dates)
    test_data = chunk_data(data_to_forecast,test_date_index,hm.chunk_length)
    forecast_length = 180 + hm.chunk_length
    ts_table = forecast(test_data,hm,forecast_length)
    return ts_table
end

function best_possible_forecast(data_to_forecast::LocationData,model::HurricaneModel,forecast_length,from_date)
    @unpack loc_data, clustering_function, submodel,fit_data = model
    
    forecast_date_index = findfirst(==(from_date),data_to_forecast.dates)
    display(forecast_date_index)
    total_cases_data = data_to_forecast.total_cases[forecast_date_index:forecast_date_index + forecast_length]
    data_chunks = mapreduce(x -> make_data_chunks(x, forecast_length,7),vcat,loc_data)

    function dist_from_x(l1)
        scale = total_cases_data[begin] / l1.total_cases[begin]
        return norm(l1.total_cases .* scale .- total_cases_data)
    end

    row_from_chunk(chunk) = (loc = chunk.name,date = chunk.dates[begin],stats = dist_from_x(chunk))
    
    display(map(row_from_chunk, data_chunks)|> DataFrame)
    best_pts = map(row_from_chunk, data_chunks) |> DataFrame |>
            df -> sort(df, :stats)[1:10,:]

    if !isempty(best_pts)
        timeseries = mapreduce(hcat,eachrow(best_pts)) do pt
            loc_ind = findfirst(p -> p.name == pt[:loc],loc_data)
            data = loc_data[loc_ind]
            index_of_date = findfirst(==(pt[:date]),data.dates) 
            timeseries_from_date = data.total_cases[index_of_date:min(end,index_of_date + forecast_length)]
            scale = total_cases_data[begin] / timeseries_from_date[begin]
            return  timeseries_from_date .* scale
        end
        return timeseries
    else
        return nothing
    end
    


end

function make_data_chunks(location_data,size,resolution)
   return map(i -> chunk_data(location_data,i,size),1:resolution:(length(location_data)-size - 1)) 
end

function chunk_data(location_data, position, length)
    @unpack name,total_cases,stringency, new_cases, new_vaccinations,total_vaccinations, population, dates = location_data
    return LocationData(
        name,
        total_cases[position:position+length+1],
        new_cases[position:position+length+1],
        new_vaccinations[position:position+length+1],
        total_vaccinations[position:position+length+1],
        dates[position:position+length+1],
        stringency[position:position+length+1],
        population,
    )
end

# source = submodel(x)
# display(length(x))
# display(filter_from_date)
# distance_to(pt) = clustering_function(pt,source)

# close_pts = filter(:date => <(filter_from_date),fit_data)  |>
#                 df -> transform(df,:stats => r->map(distance_to,r)) |>
#                 df -> sort(df,:stats_function)[1:100, 1:2]

# display(close_pts)