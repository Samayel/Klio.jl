module Klio

using Dates
using Genie

import Genie.Router: route, POST, @params
import Genie.Renderer: json

run() = begin
    Genie.config.run_as_server = true

    route("/time", method = POST) do
        Dict(:response_type => "in_channel", :text => Dates.now(Dates.UTC)) |> json
    end

    route("/choose", method = POST) do
        nick = @params(:user_name)
        text = @params(:text)
        if length(text) < 8
            reply = string("@", nick, " Du musst mir schon sagen was du mit !choose aussuchen möchtest. Das Kristallkugel-Modul bekomme ich erst in Version 2 :(")
        else
            options = split(text)
            popfirst!(options)
            if length(options) == 1
                # Ja/Nein
                choice = rand(0:1)
                reply = string("@", nick, ", ich sage: ", choice == 0 ? "Nein" : "Ja")
            else
                choice = 0
                legacy_joke = rand()
                if legacy_joke > 0.98
                    push!(options, "Ja")
                    choice = length(options)
                else
                    choice = rand(1:length(options))
                end
                reply = string("@", nick, ", ich sage: ", options[choice])
            end
        end
        Dict(:response_type => "in_channel", :text => reply) |> json
    end

    Genie.startup()
end

end # module
