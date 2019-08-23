module Klio

using HTTP
using Sockets

include("json_handler.jl")
include("mattermost_types.jl")

include("cmd_calc.jl")
include("cmd_choose.jl")
include("cmd_time.jl")

mutable struct Settings
    server_host::Sockets.IPAddr # HTTP server's IP Address to listen on
    server_port::UInt16 # HTTP server's TCP Port to listen on
    server_verbose::Bool # HTTP server's verbosity

    Settings(;
        server_host = Sockets.localhost,
        server_port = 8000,
        server_verbose = true) =
            new(server_host, server_port, server_verbose)
end

settings = Settings()

function run()
    klioRouter = HTTP.Router()

    HTTP.@register(klioRouter, "POST", "/calc", JSONHandler{OutgoingWebhookRequest}(calc))
    HTTP.@register(klioRouter, "POST", "/choose", JSONHandler{OutgoingWebhookRequest}(choose))
    HTTP.@register(klioRouter, "POST", "/time", JSONHandler{OutgoingWebhookRequest}(time))

    HTTP.serve(klioRouter, settings.server_host, settings.server_port, verbose = settings.server_verbose)
end

end
