#!/usr/bin/env julia

using Klio

Klio.settings.expl_sqlite_file = joinpath(@__DIR__, "db/expl.sqlite")

Klio.run()
