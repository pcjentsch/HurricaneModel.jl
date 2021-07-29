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
using DataStructures
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
using StatsPlots
function assess_errors_plot(location_data_list,forecast_length,hm_list)
    errors = Dict(label => [Vector{Float64}() for _ in 1:forecast_length] for (label,hm) in hm_list)
    dates = Date(2020,11,1):Day(14):Date(2021,3,1)   
    # for d in dates
    #     for loc in location_data_list[1:5]
    #         test_date_index = findfirst(==(d),loc.dates)
    #         if !isnothing(test_date_index)
    #             data = loc.total_cases[test_date_index:test_date_index + forecast_length - 1]
    #             fit_lengths_and_ts_tables = forecast_models(hm_list,d,forecast_length,loc)
    #             medians = [get_stats(ts_table[chunk_length:end,:])[1] for (chunk_length,ts_table) in fit_lengths_and_ts_tables] 
    #             display(loc.name)
    #             if all(length.(medians) .== forecast_length)
    #                 for ((label,hm),median) in zip(hm_list,medians)
    #                     push!.(errors[label],abs.(median .- data))
    #                 end
    #             end
    #         end
    #     end
    # end
    display(errors)
    for (model,model_errors) in pairs(errors)
        errors_as_array = reduce(hcat,model_errors)
        display(violin(errors_as_array; side = :left))
    end
        # p = violin(errors)
end
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
    hm_list = [("SEIRV",hm_seirv),("SIR",hm_sir),("Vanilla",hm_default)]
    yesterday = today()-Day(2)
    dates = [Date(2020,12,1)]

    data_iterator = Iterators.product(datasets, dates)
    # df = DataFrame()
    # for (data,date) in data_iterator
    #     forecast_errors,xpts = plot_forecast("$(data.name)_$date",data,hm_list,date)
    #     for (forecast_error,(name,hm)) in zip(forecast_errors,hm_list)
    #         forecast_error_as_string = map(f -> (@sprintf "%.3f" f),forecast_error)
    #         named_pts = OrderedDict("model_name " => name,"location" => data.name )
            
    #         for (xpt,ferr) in zip(xpts,forecast_error_as_string)
    #             named_pts[string(xpt)] = ferr
    #         end
    #         df_temp = DataFrame(named_pts)
    #         append!(df,df_temp; cols = :union)
    #     end
    # end 
    assess_errors_plot(location_data_list,120,hm_list)
    # CSV.write("output.csv",df)
end



end