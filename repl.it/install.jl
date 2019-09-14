using Pkg

Pkg.activate("./Klio")
Pkg.resolve()

run(`curl -g -L -f -o /home/runner/.julia/packages/Reduce/TI9IX/deps/reduce.tar.gz https://fs.quyo.net/repl.it/klio/reduce-csl_4567_amd64.tgz`)
run(`chmod u+w /home/runner/.julia/packages/Reduce/TI9IX/deps/build.jl`)
run(`sed -i -e 's|[^#]download(|#download(|g' /home/runner/.julia/packages/Reduce/TI9IX/deps/build.jl`)
Pkg.build("Reduce")

run(`./install-maxima`)

Pkg.add(PackageSpec(url="https://github.com/chschu/SQLite.jl.git"))

# ] precompile
