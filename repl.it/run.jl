using Klio
using Sockets

Klio.settings.server_host = IPv4(0)
Klio.settings.expl_sqlite_file = joinpath(kliodir, "db/expl.sqlite")

Klio.run()
