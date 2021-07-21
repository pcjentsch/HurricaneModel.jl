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
export main
include("data.jl")
include("hurricane.jl")
include("sir_submodel.jl")
include("plotting.jl")

const color_palette = cgrad(:seaborn_muted) 

diff(l) = [l[i] - l[i-1] for i = 2:length(l)]

function main()
    location_data_by_region = fetch_data_by_country_owid()
    
    # computed_aggregate_data = aggregate(location_data_by_region)
    # serialize("cache.dat", computed_aggregate_data)

    plot_forecast(location_data_by_region)
    
    # fit_animation(location_data_by_region["Canada"])
end


using Serialization
function plot_forecast(location_data_by_region)

    default(fontfamily = "Computer Modern")
    default(framestyle=:box)
    default(dpi=300)

    ontario_data = location_data_by_region["Canada"]

    aggregate_data = deserialize("cache.dat")
    
    test_fit_length= 60
    test_date = Date(2020,12,1) - Day(test_fit_length)
    test_date_index = findfirst(==(test_date),ontario_data.dates)
    test_data = chunk_data(ontario_data,test_date_index,test_fit_length)
    forecast_length = 180 + test_fit_length
    close_pts,ts_table = forecast(test_data,aggregate_data,forecast_length,location_data_by_region)
    med = map(median,eachrow(ts_table))
    uq = map(pt->quantile(pt,0.75),eachrow(ts_table))
    lq = map(pt->quantile(pt,0.25),eachrow(ts_table))
    xpts = test_date:Day(1):test_date+Day(forecast_length)
    display(length(test_date:Day(1):ontario_data.dates[end]))
    p = plot( test_date:Day(1):ontario_data.dates[end],  ontario_data.total_cases[test_date_index:end];
     label = "data", xlabel = "Day", ylabel = "Confirmed incident cases")
    plot!(p,xpts,med; ribbon = (med .- lq,uq .- med), label = "forecast", legend = :topleft, yscale = :identity, )
    # for (i,r) in enumerate(eachcol(ts_table))
    #     plot!(p,xpts,r; label = "$(close_pts[i,:loc]), $(close_pts[i,:date])")
    # end
    vspan!(p,[test_date,test_date+Day(test_fit_length)]; alpha = 0.1, label = "data used for fitting")
    savefig(p,"test_forecast.png")

    stats = mapreduce(SIR_statistics,hcat,aggregate_data[:,:stats])
    plt =scatter(stats[1,:],stats[2,:]; markersize = 2.0,
    markerstrokewidth = 0.1, xlabel = L"R_{eff}", ylabel = "Serial interval", seriescolor = color_palette, legend = false)
    savefig(plt, "scatter.png" )

end
end # module
