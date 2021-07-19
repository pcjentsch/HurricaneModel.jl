
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
        fitted_indicent_cases = [fitted_sol[i][3] - fitted_sol[i-1][3] for i in 2:(size+lookahead)]
        plot!(frame_i,xpts,fitted_indicent_cases;
         xlims = xl, ylims = yl, label = "fitted model")
        vspan!(frame_i,[begin_date,begin_date+Day(size-1)];color = :cyan, alpha = 0.1, label = "fitting window")
        
        frame(anim,frame_i)
    end
    
    gif(anim,"fitting_animation.gif"; fps = 10)

    plt2 = plot()
    plot!(plt2,[c.begin_date for c in chunks],[m[1]/m[2] for m in minimizers]; label = "R_0",ylims = [0.0,10.0])
    savefig(plt2, "parameters.png")
end