const PACKAGE_FOLDER = dirname(dirname(pathof(CompartmentalHurricane)))

"""
Returns a list of new cases on each day keyed by region. Currently using Canada.
"""
function fetch_data_by_country()
    covid_cases_path = joinpath(PACKAGE_FOLDER,"data","csse_covid_19_data","csse_covid_19_time_series","time_series_covid19_confirmed_global.csv")
    covid_cases_data = CSV.File(covid_cases_path) |> DataFrame
    cases_dates_as_strings = names(covid_cases_data)[5:end]
    # rename!(covid_cases_data,Symbol.(names(covid_cases_data)))
    # display(covid_cases_data)
    # covid_recovered_path = joinpath(PACKAGE_FOLDER,"data","csse_covid_19_data","csse_covid_19_time_series","time_series_covid19_recovered_global.csv")
    # covid_recovered_data = CSV.File(covid_recovered_path) |> DataFrame
    
    
    population_data_path = joinpath(PACKAGE_FOLDER,"data","countries_population.csv")
    population_data = CSV.File(population_data_path) |> DataFrame
    
    dates_list = Date.(cases_dates_as_strings,"mm/dd/yy") .+ Year(2000) #add 2k years cause yeears not parsed correctly
    

    cases_data = filter(:"Province/State" => ismissing,covid_cases_data) |>
                df -> filter(row -> row[end] > 0.0, df)

    cases_data_with_provinces = filter(:"Province/State" => !ismissing,covid_cases_data) |>
                df -> filter(row -> row[end] > 0.0, df) |>
                df -> groupby(df,:"Country/Region") |>
                gdf -> combine(gdf,cases_dates_as_strings .=> sum) |>
                df -> rename(df, (cases_dates_as_strings .* "_sum") .=> cases_dates_as_strings)

    append!(cases_data,cases_data_with_provinces; cols = :subset)

    rename!(population_data,:"Country_Name" => "Country/Region")
    joined_data = innerjoin(population_data,cases_data,on=:"Country/Region")

    region_cases = map(eachrow(joined_data)) do row
        ts_begin_index = findfirst(==("1/22/20"),names(row))
        # display(count(ismissing,row[:end]))
        cases_data = Vector{Float64}(row[ts_begin_index:end])
        # predictor = loess(1:length(cases_data),cases_data)
        # cases_data_smoothed = Loess.predict(predictor, 1:length(cases_data))
        pop_row = Float64(row["population_2020"])
        index_of_first_case = findfirst(>(0),cases_data)
        location_data = LocationData(cases_data[index_of_first_case:end],dates_list[index_of_first_case:end],pop_row)
        return row["Country/Region"] => location_data
    end |> Dict{String,LocationData}
    
    return region_cases
end
function is_contiguous(l)
    for i in 1:length(l)-1
        d = l[i]
        if l[i+1] != d + Day(1)
            return false
        end
    end
    return true
end

function fetch_data_by_country_owid()
    
    covid_cases_path = joinpath(PACKAGE_FOLDER,"data","owid-covid-data.csv")
    covid_cases_data = CSV.File(covid_cases_path) |> DataFrame

    locations = unique(covid_cases_data[:,:location])
    location_data_dict = Dict{String,LocationData}()
    for location in locations
        location_subset_w_missing = filter(:location =>  ==(location),covid_cases_data)
        sort!(location_subset_w_missing,:date)
        location_subset = dropmissing(location_subset_w_missing, [:new_cases_smoothed,:new_vaccinations_smoothed,:total_cases])
        new_cases_smoothed = location_subset[:,:new_cases_smoothed]       
        total_cases= location_subset[:,:total_cases]
        new_vaccinations_smoothed = location_subset[:, :new_vaccinations_smoothed]
        dates = location_subset[:,:date]
        if length(total_cases) >0
            population = location_subset[:,:population][1]
            if !is_contiguous(dates)
                display((location,dates))
            else
                display("contiguous!")
            end 
            location_data = LocationData(
                total_cases,
                new_cases_smoothed,
                new_vaccinations_smoothed,
                dates,
                population
            )
            location_data_dict[location] = location_data
        end
    end
    return location_data_dict
end

struct LocationData
    total_cases::Vector{Float64} #total cases by day
    new_cases::Vector{Float64} #total cases by day
    new_vaccinations::Vector{Float64} #total cases by day
    dates::Vector{Date} #date corresponding to total cases
    population::Float64
end


# function population()
    