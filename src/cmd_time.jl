module Time

using Dates

using ..Mattermost

function time(req)
    return OutgoingWebhookResponse(Dates.format(Dates.now(Dates.UTC), Dates.ISODateTimeFormat))
end

end
