using Pkg

Pkg.activate("./Klio")

using Klio
using Sockets

Klio.settings.server_host = IPv4(0)
Klio.settings.expl_sqlite_file = "~/db/expl.sqlite"

Klio.run()
