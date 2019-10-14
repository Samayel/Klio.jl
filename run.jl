#!/usr/bin/env julia

using Klio

ENV["JULIA_MATHKERNEL"] = joinpath(ENV["HOME"], "opt/Wolfram/Mathematica/12.0/Executables")
ENV["JULIA_MATHLINK"]   = joinpath(ENV["HOME"], "opt/Wolfram/Mathematica/12.0/SystemFiles/Libraries/Linux-x86-64")

Klio.settings.expl_sqlite_file = joinpath(@__DIR__, "db/expl.sqlite")

Klio.run()
