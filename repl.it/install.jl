using Pkg

repl_install_klio() = begin
    Pkg.resolve()

    reducedir = joinpath(dirname(Base.find_package(@__MODULE__, "Reduce")), "..")
    if !isfile(joinpath(reducedir, "deps/reduce.tar.gz"))
        run(`curl -g -L -f -o $reducedir/deps/reduce.tar.gz https://fs.quyo.net/repl.it/klio/reduce-csl_4567_amd64.tgz`)
        run(`chmod u+w $reducedir/deps/build.jl`)
        run(`sed -i -e 's|[^#]download(|#download(|g' $reducedir/deps/build.jl`)
        Pkg.build("Reduce")
    end

    if !isdir(joinpath(homedir(), "opt/maxima"))
        run(`$repldir/install-maxima`)
    end

    pkg"precompile"
end

repl_install_klio()
