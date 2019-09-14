using Pkg

repl_run_klio() = begin
    kliodir = joinpath(homedir(), "Klio")

    Pkg.activate(kliodir)

    @eval begin
        using Klio
        using Sockets
    end

    Klio.settings.server_host = IPv4(0)
    Klio.settings.expl_sqlite_file = joinpath(kliodir, "db/expl.sqlite")

    Klio.run()
end

repl_run_klio()
