module Klio

using HTTP
using Sockets

include("json_handler.jl")
include("mattermost_types.jl")

include("cmd_calc.jl")
include("cmd_choose.jl")
include("cmd_time.jl")

include("cmd_expl.jl")

mutable struct Settings
    server_host::Sockets.IPAddr # HTTP server's IP Address to listen on
    server_port::UInt16 # HTTP server's TCP Port to listen on
    server_verbose::Bool # HTTP server's verbosity
    expl_sqlite_file::String # SQLite path and file

    Settings(;
        server_host = Sockets.localhost,
        server_port = 8000,
        server_verbose = true,
        expl_sqlite_file = "/tmp/expl.sqlite") =
            new(server_host, server_port, server_verbose, expl_sqlite_file)
end

settings = Settings()

function run()
    klioRouter = HTTP.Router()

    HTTP.@register(klioRouter, "POST", "/calc", JSONHandler{OutgoingWebhookRequest}(calc))
    HTTP.@register(klioRouter, "POST", "/choose", JSONHandler{OutgoingWebhookRequest}(choose))
    HTTP.@register(klioRouter, "POST", "/time", JSONHandler{OutgoingWebhookRequest}(time))

    HTTP.@register(klioRouter, "POST", "/add", JSONHandler{OutgoingWebhookRequest}(add))

    HTTP.serve(klioRouter, settings.server_host, settings.server_port, verbose = settings.server_verbose)
end

end
