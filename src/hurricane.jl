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
    sufficiently_close_to_x(pt) = clustering_function(pt,source)
    close_pts = filter(:stats => sufficiently_close_to_x,fit_data) |>
            df -> filter(:date => <(x.dates[end] - Day(1)),df)[:,1:2]
    # display(close_pts)
    return get_predictions_from_date_time(close_pts,loc_data,forecast_length,x.total_cases[begin],x.dates[end])
end
function get_predictions_from_date_time(close_pts::DataFrame,loc_data,forecast_length,begin_cases,end_date)
    if !isempty(close_pts)
        timeseries = mapreduce(hcat,eachrow(close_pts)) do pt
            loc_ind = findfirst(p -> p.name == pt[:loc],loc_data)
            data = loc_data[loc_ind]
            index_of_date = findfirst(==(pt[:date]),data.dates) 
            permitted_ts_length = min(forecast_length,Dates.value(end_date -pt[:date]))
            timeseries_from_date = data.total_cases[index_of_date:index_of_date + permitted_ts_length]
            scale = begin_cases/ timeseries_from_date[begin]
            return  vcat(timeseries_from_date .* scale, fill(missing,max(0,forecast_length - permitted_ts_length)))
        end
        return timeseries
    else
        return nothing
    end
end


function forecast_from_date(data_to_forecast,hm,from_date)
    test_date = from_date - Day(hm.chunk_length)
    test_date_index = findfirst(==(test_date),data_to_forecast.dates)
    test_data = chunk_data(data_to_forecast,test_date_index,hm.chunk_length)
    forecast_length = 120 + hm.chunk_length
    ts_table = forecast(test_data,hm,forecast_length)
    return ts_table
end
using LinearAlgebra
function best_possible_forecast(data_to_forecast::LocationData,model::HurricaneModel,forecast_length,from_date)
    @unpack loc_data, clustering_function, submodel,fit_data = model
    
    last_date = end_date(loc_data[begin]);
    forecast_date_index = findfirst(==(from_date),data_to_forecast.dates)
    total_cases_data = data_to_forecast.total_cases[forecast_date_index : (forecast_date_index + forecast_length +1)]
    data_chunks = mapreduce(x -> make_data_chunks(x, forecast_length,7),vcat,loc_data)

    function dist_from_x(l1)
        scale = total_cases_data[begin] / l1.total_cases[begin]
        return norm(l1.total_cases .* scale .- total_cases_data)
    end

    row_from_chunk(chunk) = (loc = chunk.name,date = chunk.dates[begin],dist = dist_from_x(chunk))
    
    # display((begin_date + Day(forecast_length),last_date))
    # filter_from_date = from_date + Day(forecast_length) > from_date ?
    # from_date -  ((from_date + Day(forecast_length)) - from_date) : from_date

    best_pts = map(row_from_chunk, data_chunks) |> DataFrame |>
                df -> filter(:date => <(from_date - Day(forecast_length)),df) |>
                df -> sort(df, :dist)[1:10,1:2]
    # display(best_pts)
    return get_predictions_from_date_time(best_pts, loc_data,forecast_length,total_cases_data[begin],from_date)
end

function process_data_pairs(rest_of_the_data, size)
    data_pairs = mapreduce(make_data_pairs,vcat,rest_of_the_data) |> pairs->filter(p -> p[1].dates[begin] + Day(size) < from_date,pairs)
    xys = Vector{Tuple{Vector{Float64},Float64}}()
    for d1 in data_pairs, d2 in data_pairs
        if d2[1].dates[begin] + Day(size) <  d1[2].dates[begin]
            scale = d1[2].total_cases[begin] / d2[2].total_cases[begin]
            xy = (vcat(default_submodel(d1[1]),default_submodel(d1[2])) , norm(d1[2].total_cases .* scale .- d2[2].total_cases))
            # display(typeof(xy))
            push!(xys,xy)
        end
    end
    return xys
end
function make_dataset(loc_data_list,forecast_length,from_date)

    size = 14
        
    make_data_pairs(loc) = map(i -> (chunk_data(loc,i,size),chunk_data(loc,i,forecast_length)),1:14:(length(loc)- forecast_length - 1))
    uk_data = fetch_location("United Kingdom",loc_data_list)
    canada_data = fetch_location("Canada",loc_data_list)
    netherlands_data = fetch_location("Netherlands",loc_data_list)
    validation_data = [uk_data,canada_data,netherlands_data]
    rest_of_the_data = [loc for loc in loc_data_list if !(loc in validation_data)]   


       



    # return xys
    # for loc in loc_data_list
    #     last_date = end_date(loc[begin]);
    #     forecast_date_index = findfirst(==(from_date),data_to_forecast.dates)
    #     total_cases_data = loc.total_cases[forecast_date_index : (forecast_date_index + forecast_length +1)]
    #     data_chunks = mapreduce(x -> make_data_chunks(x, forecast_length,7),vcat,loc_data)
    #     function dist_from_x(l1)
    #         scale = total_cases_data[begin] / l1.total_cases[begin]
    #         return norm(l1.total_cases .* scale .- total_cases_data)
    #     end

    #     row_from_chunk(chunk) = (chunk = chunk, x = default_submodel(chunk) , y = dist_from_x(chunk))
        
    #     # display((begin_date + Day(forecast_length),last_date))
    #     # filter_from_date = from_date + Day(forecast_length) > from_date ?
    #     # from_date -  ((from_date + Day(forecast_length)) - from_date) : from_date

    #     best_pts = map(row_from_chunk, data_chunks) |> DataFrame |>
    #                 df -> filter(:date => <(from_date - Day(1)),df) |>
    #                 df -> sort(df, :stats)[1:50,1:2]
    # end
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