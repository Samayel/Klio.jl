module Klio

using Dates
using Genie
using Reduce

import Genie.Router: route, POST, @params
import Genie.Renderer: json

run() = begin
    Genie.config.run_as_server = true

    route("/time", method = POST) do
        Dict(:response_type => "in_channel", :text => Dates.now(Dates.UTC)) |> json
    end

    route("/calc", method = POST) do
        message = @params(:JSON_PAYLOAD)
        question = replace(message["text"], "!calc " => "")
        answer = question |> rcall
        Dict(:response_type => "in_channel", :text => answer) |> json
    end

    route("/choose", method = POST) do
        nick = @params(:user_name)
        text = @params(:text)
        
        options = split(text)
        # Weg mit dem !choose
        popfirst!(options)
        
        if length(options) == 0
            reply = string("@", nick, ", du musst mir schon sagen was du mit !choose aussuchen möchtest. Das Kristallkugel-Modul bekomme ich erst in Version 2 :(")
        elseif length(options) == 1
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
        Dict(:response_type => "in_channel", :text => reply) |> json
    end

    Genie.startup()
end

end # module
