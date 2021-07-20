module CompartmentalHurricane
using Dates: Locale
using Base: indent_width
using DataFrames: append_rows!
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
export main
include("data.jl")
include("hurricane.jl")
include("sir_submodel.jl")
include("plotting.jl")

diff(l) = [l[i] - l[i-1] for i = 2:length(l)]

function main()
    location_data_by_region = fetch_data_by_country_owid()
    
    plot_forecast(location_data_by_region)
    
    # fit_animation(location_data_by_region["Canada"])

    return location_data_by_region["Canada"]
end


using Serialization
function plot_forecast(location_data_by_region)

    ontario_data = location_data_by_region["Canada"]
    # computed_aggregate_data = aggregate(location_data_by_region)
    # serialize("cache.dat", computed_aggregate_data)
    aggregate_data = deserialize("cache.dat")
    test_date = Date(2020,12,1)
    test_date_index = findfirst(==(test_date),ontario_data.dates)
    test_fit_length=80
    test_data = chunk_data(ontario_data,test_date_index,test_fit_length)
    forecast_length = 150
    ts_table = forecast(test_data,aggregate_data,forecast_length,location_data_by_region)
    med = map(median,eachrow(ts_table))
    uq = map(pt->quantile(pt,0.75),eachrow(ts_table))
    lq = map(pt->quantile(pt,0.25),eachrow(ts_table))
    xpts = test_date:Day(1):test_date+Day(forecast_length)    
    p = plot( test_date:Day(1):ontario_data.dates[end],  ontario_data.total_cases[test_date_index:end]; label = "data" )
    plot!(p,xpts,med; ribbon = (med .- lq,uq .- med), label = "forecast")
    savefig(p,"test_forecast.png")

    stats = mapreduce(SIR_statistics,hcat,aggregate_data[:,:stats])
    plt =scatter(stats[1,:],stats[2,:])
    savefig(plt, "scatter.png" )

end
end # module
