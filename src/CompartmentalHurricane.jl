module CompartmentalHurricane 
using ColorSchemes
using OrdinaryDiffEq
using CSV
using DataFrames
using DataFramesMeta
using OrdinaryDiffEq
using Dates
using Plots
using ThreadsX
using StatsBase
using BenchmarkTools
using BlackBoxOptim
using Serialization
using StaticArrays
export main

const PACKAGE_FOLDER = dirname(dirname(pathof(CompartmentalHurricane)))
const color_palette = cgrad(:seaborn_muted) 


include("data.jl")
include("default_submodel.jl")
include("hurricane.jl")
include("sir_submodel.jl")
include("plotting.jl")


function main()
    location_data_list = fetch_data_by_country_owid()
    # location_data_list = fetch_data_by_country_vanilla_model()

    hm = HurricaneModel(default_submodel,default_dist,location_data_list, 14,1)
    canada_data = location_data_list[findfirst(l-> l.name == "United Kingdom",location_data_list)]
    display(canada_data)

    # # close_pts,ts_table = forecast(canada_data,hm,forecast_length)
    # # display(close_pts)

    # # @btime benchmark_submodel($data)
    # # chunks = make_data_chunks(data,14,1)[begin:388]
    # # return fit_submodel(default_submodel,chunks)

    # # computed_aggregate_data = compute_timeseries_statistics(
    # #     "vanilla_hurricane.dat",default_submodel,location_data_by_region
    # # )

    plot_forecast(canada_data,(d,l) -> forecast(d,hm,l))
    
    # # fit_animation(location_data_by_region["Canada"])
    # # return ts_table
    return canada_data
end



end # module
