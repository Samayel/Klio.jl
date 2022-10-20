module Choose

using ..MattermostTypes

function choose(req)
    options = split(req.text)
    # Weg mit dem !choose
    popfirst!(options)

    if length(options) == 0
        reply = string("@", req.user_name, ", du musst mir schon sagen was du mit !choose aussuchen möchtest. Das Kristallkugel-Modul bekomme ich erst in Version 2 :(")
    elseif length(options) == 1
        # Ja/Nein
        choice = rand(0:1)
        reply = string("@", req.user_name, ", ich sage: ", choice == 0 ? "Nein" : "Ja")
    else
        choice = 0
        legacy_joke = rand()
        if legacy_joke > 0.98
            push!(options, "Ja")
            choice = length(options)
        else
            choice = rand(1:length(options))
        end
        reply = string("@", req.user_name, ", ich sage: ", options[choice])
    end

    return OutgoingWebhookResponse(reply)
end

end
