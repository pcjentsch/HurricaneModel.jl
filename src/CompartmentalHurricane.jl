module CompartmentalHurricane 
using ColorSchemes
using OrdinaryDiffEq
using CSV
using LabelledArrays
using DataFrames
using DataFramesMeta
import Base:length
using OrdinaryDiffEq
using Dates
using Plots
using ThreadsX
using StatsBase
using BenchmarkTools
using BlackBoxOptim
using Serialization
using StaticArrays
using UnPack
using LinearAlgebra
export main

const PACKAGE_FOLDER = dirname(dirname(pathof(CompartmentalHurricane)))
const color_palette = cgrad(:seaborn_muted)[2:end]


include("data.jl")
include("default_submodel.jl")
include("hurricane.jl")
include("sir_submodel.jl")
include("seirv_submodel.jl")
include("plotting.jl")
using Printf
function main()
    location_data_list = fetch_data_by_country_owid()
    # location_data_list = fetch_data_by_country_vanilla_model()
    uk_data = fetch_location("United Kingdom",location_data_list)
    canada_data = fetch_location("Canada",location_data_list)
    netherlands_data = fetch_location("Netherlands",location_data_list)
    datasets = [canada_data,netherlands_data,uk_data]
    hm_default = HurricaneModel(default_submodel,default_dist,location_data_list, 14,1)
    hm_sir = HurricaneModel(sir_submodel,sir_dist,location_data_list, 60,3; cache = "sir_cache.dat")
    hm_seirv = HurricaneModel(seirv_submodel,seirv_dist,location_data_list, 60,3; cache = "seirv_cache.dat")
    hm_list = [("SEIRV",hm_seirv),("Vanilla",hm_default)]
    yesterday = today()-Day(2)
    dates = [Date(2020,12,1),yesterday]

    data_iterator = Iterators.product(datasets, dates)
    df = DataFrame()
    for (data,date) in data_iterator
        forecast_errors = plot_forecast("$(data.name)_$date",data,hm_list,date)
        for (forecast_error,(name,hm)) in zip(forecast_errors,hm_list)
            forecast_error_as_string = map(f -> (@sprintf "%.3f" f),forecast_error)
            push!(df,(model_name = name,date = date,location = data.name, forecast_error = forecast_error_as_string))
        end
    end 

    # CSV.write("output.csv",df)
end
function assess_errors(location_data_list,forecast_length)
    errors = Vector{Vector{Float64}}(undef, forecast_length)    
    for loc in location_data_list

    end

end


end