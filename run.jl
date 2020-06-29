#!/usr/bin/env julia

using Klio

ENV["JULIA_MATHKERNEL"] = joinpath(ENV["HOME"], "opt/Wolfram/Mathematica/12.1/Executables/WolframKernel")
ENV["JULIA_MATHLINK"]   = joinpath(ENV["HOME"], "opt/Wolfram/Mathematica/12.1/SystemFiles/Libraries/Linux-x86-64/libML$(Sys.WORD_SIZE)i4")

Klio.settings.expl_sqlite_file = joinpath(@__DIR__, "db/expl.sqlite")

Klio.run()
