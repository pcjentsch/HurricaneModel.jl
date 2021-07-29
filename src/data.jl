
function is_contiguous(l)
    for i in 1:length(l)-1
        d = l[i]
        if l[i+1] != d + Day(1)
            return false
        end
    end
    return true
end
function fetch_data_by_country_vanilla_model()
    
    covid_cases_path = joinpath(PACKAGE_FOLDER,"data","taha-covid-data.csv")
    covid_cases_data = CSV.File(covid_cases_path) |> DataFrame |> df -> df[:,2:end]

    provinces = covid_cases_data[3,2:end] |> Vector |> v -> replace( v, missing => "")
    countries = covid_cases_data[4,2:end] |> Vector |> v -> replace( v, missing => "")
    
    location_data_list = Vector{LocationData}()
    for (i,(province, country)) in enumerate(zip(provinces, countries))
        location_label = isempty(province) ? country : "$province, $country" 
        total_cases = covid_cases_data[20:end,i+1] |> v-> replace( v, missing => "0.0") |> v -> parse.(Float64,v)
        dates = covid_cases_data[20:end,1] |> v-> Date.(v, "mm/dd/yyyy")
        location_data = LocationData(
                location_label,
                total_cases,
                zeros(length(total_cases)),
                zeros(length(total_cases)),
                zeros(length(total_cases)),
                dates,
                1,
        )
            push!(location_data_list,location_data)
    end
    return location_data_list
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
        stringency = replace(location_subset[:,:stringency_index], missing => 25.0)
        # display(stringency)
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
                stringency,
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
    stringency::Vector{Float64}
    population::Float64
end

length(x::LocationData) = length(x.dates)
end_date(x::LocationData) = x.dates[end] 
function fetch_location(loc::String, loc_data_list::Vector{LocationData})
    ind = findfirst(l-> l.name == loc,loc_data_list)
    return loc_data_list[ind]
end

# function population()
    
function get_stats(ts_table)
    med = Float64[]
    lq = Float64[]
    uq = Float64[]
    for r in eachrow(ts_table)
       if all(ismissing.(r))
           break
       else
           push!(med,median(skipmissing(r)))
           push!(lq,quantile(skipmissing(r),0.75))
           push!(uq,quantile(skipmissing(r),0.25))
       end
   end
   return med,lq,uq
end