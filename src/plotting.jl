using LaTeXStrings
function fit_animation(location_data)

    default(fontfamily = "Computer Modern")
    default(framestyle=:box)
    default(dpi=300) 
    (; new_cases, total_cases, dates) = location_data
    plt = plot(dates,new_cases; 
        xlabel = "Date",
        ylabel = "Case incidence",
        title = "Fitting case incidence in Canada",
        label = "Case incidence in Canada",
        size = (800,600),
        dpi = 200,
        legend = :topleft,
    )
    yl = ylims(plt)
    xl = xlims(plt)
    size = 40
    lookahead = 500
    chunks = make_data_chunks(location_data,size,5)
    minimizers = fit_submodel(chunks)


    anim = Animation()


    for (minimizer,chunk) in zip(minimizers,chunks)
        begin_date = chunk.dates[begin]
        xpts = begin_date:Day(1):begin_date+Day(size + lookahead - 2)    
        frame_i = deepcopy(plt)
        fitted_sol = model(minimizer, chunk ;extend = lookahead)
        fitted_indicent_cases = [fitted_sol[i][3] - fitted_sol[i-1][3] for i in 2:(size+lookahead)]
        # display(length(xpts))
        # display(fitted_indicent_cases)
        plot!(frame_i,xpts,fitted_indicent_cases;
         xlims = xl, ylims = yl, label = "fitted model")
        vspan!(frame_i,[begin_date,begin_date+Day(size-1)];color = :cyan, alpha = 0.1, label = "fitting window")
        
        frame(anim,frame_i)
    end
    
    gif(anim,"fitting_animation.gif"; fps = 10)

    plt2 = plot()
    plot!(plt2,[c.dates[begin] for c in chunks],[m[1]/m[2] for m in minimizers]; label = L"R_{eff}")
    plot!(plt2,[c.dates[begin] for c in chunks],[0.5 * 1/m[2] for m in minimizers];
     label = "serial interval",dpi = 300, legend = :topright)
    savefig(plt2, "parameters.png")
end