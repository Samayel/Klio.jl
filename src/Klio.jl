module Klio

using HTTP
using Sockets
using TimeZones
using Dates

include("json_handler.jl")
include("mattermost_types.jl")

include("cmd_calc.jl")
include("cmd_choose.jl")
include("cmd_time.jl")
include("cmd_expl.jl")

using .Mattermost
using .JSON

mutable struct Settings
    server_host::Sockets.IPAddr # HTTP server's IP Address to listen on
    server_port::UInt16 # HTTP server's TCP Port to listen on
    server_verbose::Bool # HTTP server's verbosity
    expl_sqlite_file::String # SQLite path and file
    expl_time_zone::TimeZone # time zone used for DateTime formatting in !expl responses
    expl_datetime_format::DateFormat # format for DateTime in !expl

    Settings(;
        server_host = Sockets.localhost,
        server_port = 8000,
        server_verbose = true,
        expl_sqlite_file = "/tmp/expl.sqlite",
        expl_time_zone = tz"Europe/Berlin",
        expl_datetime_format = dateformat"dd.mm.YYYY HH:MM") =
            new(server_host, server_port, server_verbose, expl_sqlite_file, expl_time_zone, expl_datetime_format)
end

settings = Settings()

function run()
    klioRouter = HTTP.Router()

    wrap(h) = JSONHandler(OutgoingWebhookRequest, h)

    HTTP.@register(klioRouter, "POST", "/calc", wrap(Calc.calc))
    HTTP.@register(klioRouter, "POST", "/choose", wrap(Choose.choose))
    HTTP.@register(klioRouter, "POST", "/time", wrap(Time.time))

    HTTP.@register(klioRouter, "POST", "/add", wrap(Expl.add))
    HTTP.@register(klioRouter, "POST", "/expl", wrap(Expl.expl))
    HTTP.@register(klioRouter, "POST", "/del", wrap(Expl.del))
    HTTP.@register(klioRouter, "POST", "/find", wrap(Expl.find))
    HTTP.@register(klioRouter, "POST", "/topexpl", wrap(Expl.topexpl))

    HTTP.@register(klioRouter, "GET", "/expl", Expl.www_expl)
    HTTP.@register(klioRouter, "GET", "/find", Expl.www_find)

    HTTP.serve(klioRouter, settings.server_host, settings.server_port, verbose = settings.server_verbose)
end

end
