
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
    location_data_list = Vector{LocationData}()
    for location in locations
        location_subset_w_missing = filter(:location =>  ==(location),covid_cases_data)
        sort!(location_subset_w_missing,:date)
        location_subset = dropmissing(location_subset_w_missing, [:new_cases_smoothed,:total_cases,:population])
        new_cases_smoothed = location_subset[:,:new_cases_smoothed]       
        total_cases= location_subset[:,:total_cases]
        dates = location_subset[:,:date]

        new_vaccinations_smoothed = replace(location_subset[:, :new_vaccinations_smoothed],missing => 0.0)
        total_vaccinations = replace(location_subset[:, :people_fully_vaccinated],missing => 0.0)
        if length(total_cases) >0
            population = location_subset[:,:population][1]
            if !is_contiguous(dates)
                display((location,dates))
                throw(error("dates not contiguous!"))
            end
            location_data = LocationData(
                location,
                total_cases,
                new_cases_smoothed,
                new_vaccinations_smoothed,
                total_vaccinations,
                dates,
                population
            )
            push!(location_data_list,location_data)
        end
    end
    return location_data_list
end

struct LocationData
    name::String #name of region 
    total_cases::Vector{Float64} #total cases by day
    new_cases::Vector{Float64} #total cases by day
    new_vaccinations::Vector{Float64} #total cases by day
    total_vaccinations::Vector{Float64} #total cases by day
    dates::Vector{Date} #date corresponding to total cases
    population::Float64
end
import Base:length
length(x::LocationData) = length(x.dates)
# function population()
    