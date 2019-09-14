using Pkg

repl_install_klio() = begin
    Pkg.resolve()

    reducedir = joinpath(homedir(), ".julia/packages/Reduce/TI9IX")
    run(`curl -g -L -f -o $reducedir/deps/reduce.tar.gz https://fs.quyo.net/repl.it/klio/reduce-csl_4567_amd64.tgz`)
    run(`chmod u+w $reducedir/deps/build.jl`)
    run(`sed -i -e 's|[^#]download(|#download(|g' $reducedir/deps/build.jl`)
    Pkg.build("Reduce")

    run(`$repldir/install-maxima`)

    Pkg.add(PackageSpec(url="https://github.com/chschu/SQLite.jl.git"))

    # ] precompile
end

repl_install_klio()
