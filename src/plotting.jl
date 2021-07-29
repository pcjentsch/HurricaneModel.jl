using LaTeXStrings
function fit_animation(compartmental_submodel,compartmental_model,location_data)

    default(fontfamily = "Computer Modern")
    default(framestyle=:box)
    default(dpi=300) 

    @unpack new_cases, new_vaccinations,total_vaccinations, total_cases, dates = location_data

    plt1 = plot(dates,new_cases; 
        xlabel = "Date",
        ylabel = "Case incidence",
        label = "Case incidence in Canada",
        legend = :topleft,
    )
    plt2 = plot(dates,total_vaccinations; 
        xlabel = "Date",
        ylabel = "Vaccinations incidence",
        label = "Vaccinations in Canada",
        legend = :topleft,
    )

    (xl1,yl1) =(xlims(plt1), ylims(plt1))
    (xl2,yl2) =(xlims(plt2), ylims(plt2))
    size = 60
    lookahead = 500
    chunks = make_data_chunks(location_data,size,5)
    minimizers = ThreadsX.map(compartmental_submodel,chunks)

    anim = Animation()

    for (minimizer,chunk) in zip(minimizers,chunks)
        begin_date = chunk.dates[begin]
        xpts = begin_date:Day(1):begin_date+Day(size + lookahead - 1)    
        frame_i_panel_1 = deepcopy(plt1)
        frame_i_panel_2= deepcopy(plt2)
        fitted_sol = compartmental_model(minimizer, chunk ;extend = lookahead).u
    
        fitted_indicent_cases = [fitted_sol[i].C - fitted_sol[i-1].C for i in 2:(size+lookahead)]
        fitted_total_vaccinations = [fitted_sol[i].V for i in 1:(size+lookahead)]
        plot!(frame_i_panel_1,xpts[1:end-1],fitted_indicent_cases;
         xlims = xl1, ylims = yl1, label = "fitted model")
        plot!(frame_i_panel_2,xpts,fitted_total_vaccinations;
         xlims = xl2, ylims = yl2, label = "fitted model")

        vspan!(frame_i_panel_1,[begin_date,begin_date+Day(size-1)];color = :cyan, alpha = 0.1, label = "fitting window")
        vspan!(frame_i_panel_2,[begin_date,begin_date+Day(size-1)];color = :cyan, alpha = 0.1, label = "fitting window")
        
        frame(anim,plot(frame_i_panel_1,frame_i_panel_2; layout = (1,2), size = (800,600)))
    end
    
    gif(anim,"fitting_animation.gif"; fps = 10)
    # plt2 = plot()
    # plot!(plt2,[c.dates[begin] for c in chunks],[m[1]/m[2] for m in minimizers]; label = L"R_{eff}")
    # plot!(plt2,[c.dates[begin] for c in chunks],[0.5 * 1/m[2] for m in minimizers];
    #  label = "serial interval",dpi = 300, legend = :topright)
    # savefig(plt2, "parameters.png")
end
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

function plot_forecast(fname,loc_data,hm_list,from_date)
    default(fontfamily = "Computer Modern")
    default(framestyle=:box)
    default(dpi=300)
    forecast_length = 120
    fit_lengths_and_ts_tables = forecast_models(hm_list,from_date,forecast_length,loc_data)
    forecasts = zip(fit_lengths_and_ts_tables...) |> collect
    
    forecast_labels = [(label for (label,hm) in hm_list)...,]

    test_date = from_date - Day(60)
    test_date_index = findfirst(==(test_date),loc_data.dates)

    data_to_compare =  loc_data.total_cases[test_date_index:min(end,test_date_index + forecast_length + 60)]
    p = plot( test_date:Day(1):test_date + Day(length(data_to_compare)-1),data_to_compare ;
     label = "Data", xlabel = "Day", ylabel = "Confirmed incident cases")

    errlist = []
    for (chunk_length,ts_table,label,color) in zip(forecasts...,forecast_labels,color_palette)
        if !isempty(ts_table)
            xpts = from_date-Day(chunk_length):Day(1):from_date+Day(forecast_length) |> collect
            med,lq,uq = get_stats(ts_table)
            if !any(isempty.(med))
                plot!(p,xpts[1:length(med)],med; ribbon = (med .- lq,uq .- med),
                 legend = :topleft, yaxis = :log10,label,seriescolor = color)
            end
            err = [data_i - forecast for (data_i,forecast) in zip(med,loc_data.total_cases[test_date_index:end])]
            push!(errlist,err[chunk_length:end])
        end
    end
    # yl = ylims(p)
    # ylims!(p,(yl[1],1e7))
    vspan!(p,[test_date,test_date+Day(60)]; alpha = 0.1, label = "Data used for fitting")
    savefig(p,joinpath(PACKAGE_FOLDER,"plots","$fname.png"))
    display(length.(errlist))
    return errlist
end
# stats = mapreduce(SIR_statistics,hcat,aggregate[:,:stats])
# plt =scatter(stats[1,:],stats[2,:]; markersize = 2.0,
# markerstrokewidth = 0.1, xlabel = L"R_{eff}", ylabel = "Serial interval", seriescolor = color_palette, legend = false)
# savefig(plt, "scatter.png" )