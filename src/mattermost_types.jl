module Mattermost

using JSON2

export OutgoingWebhookRequest, OutgoingWebhookResponse, OutgoingWebhookResponseType

"""
    OutgoingWebhookRequest
Request type for outgoing webhooks. This is just a subset of the attributes.
See https://developers.mattermost.com/integrate/outgoing-webhooks/ for a
somewhat complete description of the JSON format.
"""
struct OutgoingWebhookRequest
    text::String
    user_name::String
    OutgoingWebhookRequest(; text, user_name, kwargs...) = new(text, user_name)
end

# format specification for OutgoingWebhookRequest
# keywordargs: parse arbitrarily ordered and extra fields
JSON2.@format OutgoingWebhookRequest keywordargs begin
end

"""
    OutgoingWebhookResponseType

Enum for `response_type`. Can be post (default if not specified) or comment.
"""
@enum OutgoingWebhookResponseType post comment

"""
    OutgoingWebhookResponse
Response type for outgoing webhooks. This is just a subset of the attributes.
See https://developers.mattermost.com/integrate/outgoing-webhooks/ for a
somewhat complete description of the JSON format.
"""
struct OutgoingWebhookResponse
    text::String
    response_type::Union{OutgoingWebhookResponseType, Nothing}

    OutgoingWebhookResponse(text, response_type = nothing) = new(text, response_type)
end

# format specification for OutgoingWebhookResponse
JSON2.@format OutgoingWebhookResponse begin
    # omitempty=true: don't write JSON null value for nothing
    response_type => (omitempty = true,)
end

end
