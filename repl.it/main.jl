module Repl

const kliodir = joinpath(homedir(), "Klio")
const repldir = joinpath(kliodir, "repl.it")

Pkg.activate(kliodir)

include(joinpath(repldir, "install.jl"))
include(joinpath(repldir, "run.jl"))

end
