#!/usr/bin/env julia

ENV["JULIA_MATHKERNEL"] = "/usr/local/Wolfram/WolframEngine/12.3/Executables/WolframKernel"
ENV["JULIA_MATHLINK"]   = "/usr/local/Wolfram/WolframEngine/12.3/SystemFiles/Libraries/Linux-x86-64/libML$(Sys.WORD_SIZE)i4"

using Pkg
Pkg.instantiate()
Pkg.precompile()

using Klio
