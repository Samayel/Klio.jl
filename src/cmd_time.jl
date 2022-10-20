module Time

using Dates

using ..MattermostTypes

function time(req)
    return OutgoingWebhookResponse(Dates.format(Dates.now(Dates.UTC), Dates.ISODateTimeFormat))
end

end
