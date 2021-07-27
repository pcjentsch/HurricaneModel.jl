struct HurricaneModel{F,G,T}
    submodel::F
    clustering_function::G
    loc_data::Vector{LocationData}
    fit_data::T
    function HurricaneModel(submodel::F,clustering_function::G,loc_data,length,spacing; cache = "cache.dat") where {F<:Function,G<:Function}
        data_chunks = mapreduce(x -> make_data_chunks(x, length,spacing),vcat,loc_data)

        row_from_chunk(chunk) = (loc = chunk.name,date = chunk.dates[begin],stats = submodel(chunk))

        if !ispath(cache)  
            df = ThreadsX.map(row_from_chunk,  data_chunks) |> DataFrame 
            serialize(cache,df)
        else
            df = deserialize(cache)
        end
        return new{F,G,typeof(df)}(submodel,clustering_function,loc_data,df)
    end
end

function forecast(x::LocationData,model::HurricaneModel,forecast_length)
    (;loc_data, clustering_function, submodel,fit_data) = model

    source = submodel(x)
    display(source)
    begin_date = x.dates[begin]
    sufficiently_close_to_x(pt) = clustering_function(pt,source)
    close_pts = filter(:stats => sufficiently_close_to_x,fit_data) |>
            df -> filter(:date => <(begin_date - Day(length(x))),df) 
    
    display(close_pts)

    timeseries = mapreduce(hcat,eachrow(close_pts)) do pt
        loc_ind = findfirst(p -> p.name == pt[:loc],loc_data)
        data = loc_data[loc_ind ]
        index_of_date = findfirst(==(pt[:date]),data.dates) 
        timeseries_from_date = data.total_cases[index_of_date:min(end,index_of_date + forecast_length)]
        scale = x.total_cases[begin] / timeseries_from_date[begin]
        return  timeseries_from_date .* scale
    end
    
    # display(median_forecast)
    return close_pts, timeseries
end

function make_data_chunks(location_data,size,resolution)
   return map(i -> chunk_data(location_data,i,size),1:resolution:(length(location_data)-size - 1)) 
end

function chunk_data(location_data, position, length)
    (; name,total_cases, new_cases, new_vaccinations,total_vaccinations, population, dates) = location_data
    return LocationData(
        name,
        total_cases[position:position+length+1],
        new_cases[position:position+length+1],
        new_vaccinations[position:position+length+1],
        total_vaccinations[position:position+length+1],
        dates[position:position+length+1],
        population,
    )
end

