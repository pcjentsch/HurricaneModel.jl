module CompartmentalHurricane
using Optim: minimizer
using Dates: default
using DataFrames: Dict
using Base: Float64
using CSV
using DataFrames
using DataFramesMeta
using OrdinaryDiffEq
using Dates
using Plots
using GalacticOptim, Optim
export main
include("data.jl")
include("submodel.jl")
include("plotting.jl")

diff(l) = [l[i] - l[i-1] for i = 2:length(l)]

function main()
    location_data_by_region = fetch_data_by_country()
    ontario_data = location_data_by_region["Ontario"]

    # display(test_ts)
    # display(unique(dates))
    # plot(dates,test_ts)
    
    chunks = make_data_chunks(ontario_data,30)
     
    fit_submodel(chunks[1])


end

function make_data_chunks(location_data,size)
    (; cases, population, dates) = location_data
    daily_case_incidence = diff(cases)

     return map(50:length(cases)-size-1) do i
        DataChunk(
            daily_case_incidence[i:i+size],
            dates[i],
            population,
            cases[i-10] #arbitrary
        )
    end
end


end # module
