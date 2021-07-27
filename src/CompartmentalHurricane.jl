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

    uk_data = location_data_list[findfirst(l-> l.name == "United Kingdom",location_data_list)]

    
    hm = HurricaneModel(default_submodel,default_dist,location_data_list, 14,1)
    hm_sir = HurricaneModel(sir_submodel,sir_dist,location_data_list, 60,5; cache = "sir_cache.dat")

    plot_forecast("vanilla_forecast",uk_data,(d,l) -> forecast(d,hm,l,),14,Date(2020,12,1))
    plot_forecast("sir_forecast",uk_data,(d,l) -> forecast(d,hm_sir,l,),60,Date(2020,12,1))
    
    # return canada_data
end



end # module
