using Dates

function time(req::OutgoingWebhookRequest)::OutgoingWebhookResponse
    return OutgoingWebhookResponse(Dates.format(Dates.now(Dates.UTC), Dates.ISODateTimeFormat))
end
