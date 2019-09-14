module Repl

const kliodir = joinpath(homedir(), "Klio")
const repldir = joinpath(kliodir, "repl.it")

using Pkg
Pkg.activate(kliodir)

include(joinpath(repldir, "install.jl"))

ENV["PATH"] = joinpath(homedir(), "opt/maxima/usr/bin") * ":" * ENV["PATH"]

include(joinpath(repldir, "run.jl"))

end
