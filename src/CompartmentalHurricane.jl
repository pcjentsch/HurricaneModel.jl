module CompartmentalHurricane
using OrdinaryDiffEq: ForwardDiff, beta1_default
using Dates: length
using OrdinaryDiffEq
using CSV
using DataFrames
using DataFramesMeta
using OrdinaryDiffEq
using Dates
using Plots
using ThreadsX
using BenchmarkTools
using BlackBoxOptim
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
    
    chunks = make_data_chunks(ontario_data,40,7)
    # models_dict = ThreadsX.map(collect(keys(location_data_by_region))) do region_key
    #     region_data = location_data_by_region[region_key]
    #     display(region_key)
    #     region_data_chunks = make_data_chunks(region_data,30,7)
        
    #     models = map(fit_submodel, region_data_chunks)
    #     return region_key => models
    # end |> Dict

    # fit_submodel(chunks[50])

    fit_animation(ontario_data)
end

function make_data_chunks(location_data,size,resolution)
    (; cases, population, dates) = location_data
    daily_case_incidence = diff(cases)

    return map(50:resolution:length(cases)-size-1) do i
        DataChunk(
            daily_case_incidence[i:i+size],
            dates[i],
            population,
            cases[i-10] #guess
        )
    end
end

function fit_animation(location_data)
    (; cases, population, dates) = location_data
    daily_case_incidence =  diff(cases)
    plt = plot(dates[2:end],daily_case_incidence; 
        xlabel = "Date",
        ylabel = "Case incidence",
        title = "Fitting case incidence in Ontario, Canada",
        label = "Case incidence in Ontario, Canada"
    )
    yl = ylims(plt)
    xl = xlims(plt)
    size = 90
    lookahead = 500
    chunks = make_data_chunks(location_data,size,5)
    minimizers = ThreadsX.map(fit_submodel,chunks)


    anim = Animation()


    for (minimizer,chunk) in zip(minimizers,chunks)
        begin_date = chunk.begin_date
        xpts = begin_date:Day(1):begin_date+Day(size + lookahead -2)    
        frame_i = deepcopy(plt)
        fitted_sol = model(minimizer, chunk ;extend = lookahead)
        fitted_indicent_cases = [fitted_sol[i][4] - fitted_sol[i-1][4] for i in 2:(size+lookahead)]
        plot!(frame_i,xpts,fitted_indicent_cases;
         xlims = xl, ylims = yl, label = "fitted model")
        vspan!(frame_i,[begin_date,begin_date+Day(size-1)];color = :cyan, alpha = 0.1, label = "fitting window")
        
        frame(anim,frame_i)
    end
    
    gif(anim,"fitting_animation.gif"; fps = 10)

    plt2 = plot()
    plot!(plt2,[c.begin_date for c in chunks],[m[1]/m[2] for m in minimizers]; label = "β",ylims = [0.0,10.0])
    # plot!(plt2,[c.begin_date for c in chunks],[m[2] for m in minimizers]; label = "γ")
    savefig(plt2, "parameters.png")
end

end # module
