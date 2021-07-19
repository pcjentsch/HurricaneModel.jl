const PACKAGE_FOLDER = dirname(dirname(pathof(CompartmentalHurricane)))
"""
Returns a list of new cases on each day keyed by region. Currently using Canada.
"""
function fetch_data_by_country()
    covid_cases_path = joinpath(PACKAGE_FOLDER,"data","csse_covid_19_data","csse_covid_19_time_series","time_series_covid19_confirmed_global.csv")
    covid_cases_data = CSV.File(covid_cases_path) |> DataFrame
    
    # covid_recovered_path = joinpath(PACKAGE_FOLDER,"data","csse_covid_19_data","csse_covid_19_time_series","time_series_covid19_recovered_global.csv")
    # covid_recovered_data = CSV.File(covid_recovered_path) |> DataFrame
    
    


    
    population_data_path = joinpath(PACKAGE_FOLDER,"data","populations_canada.csv")
    population_data = CSV.File(population_data_path) |> DataFrame
    

    canada_cases_data = @subset(covid_cases_data, :"Country/Region" .== "Canada" .&& :"Lat" .> 0.0)
    cases_dates_as_strings = names(canada_cases_data)[5:end]
    dates_list = Date.(cases_dates_as_strings,"mm/dd/yy") .+ Year(2000) #add 2k years cause yeears not parsed correctly
    
    # region_cases = innerjoin(population_data,)


    rename!(population_data,:"GEO" => "Province/State")
    joined_data = innerjoin(population_data,canada_cases_data,on=:"Province/State")
    
    region_cases = map(eachrow(joined_data)) do row
        ts_begin_index = findfirst(==("1/22/20"),names(row))
        # display(count(ismissing,row[:end]))
        cases_data = Vector{Float64}(row[ts_begin_index:end])
        pop_row = Float64(row["VALUE"])
        index_of_first_case = findfirst(>(0),cases_data)
        location_data = LocationData(cases_data[index_of_first_case:end],dates_list[index_of_first_case:end],pop_row)
        return row["Province/State"] => location_data
    end |> Dict{String,LocationData}
    
    return region_cases
end

struct LocationData
    cases::Vector{Float64} #total cases by day
    dates::Vector{Date} #date corresponding to total cases
    population::Float64
end


# function population()
    