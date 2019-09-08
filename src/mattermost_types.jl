module Mattermost

using JSON2

export OutgoingWebhookRequest, OutgoingWebhookResponse, OutgoingWebhookResponseType, MessageAttachment

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
    MessageAttachment
Message attachment type. This is just a subset of the attributes.
See https://docs.mattermost.com/developer/message-attachments.html for a
documentation of the other attributes.
"""
struct MessageAttachment
    fallback::String
    title::String
    text::String
end

"""
    OutgoingWebhookResponse
Response type for outgoing webhooks. This is just a subset of the attributes.
See https://developers.mattermost.com/integrate/outgoing-webhooks/ for a
somewhat complete description of the JSON format.
"""
struct OutgoingWebhookResponse
    text::Union{String, Nothing}
    response_type::Union{OutgoingWebhookResponseType, Nothing}
    attachments::Union{AbstractArray{MessageAttachment}, Nothing}

    OutgoingWebhookResponse(text::String, attachments = nothing, response_type = nothing) = new(text, response_type, attachments)
    OutgoingWebhookResponse(attachments::Vector{MessageAttachment}, response_type = nothing) = new(nothing, response_type, attachments)
end

# format specification for OutgoingWebhookResponse
JSON2.@format OutgoingWebhookResponse begin
    # omitempty=true: don't write JSON null value for nothing
    text => (omitempty=true,)
    response_type => (omitempty=true,)
    attachments => (omitempty=true,)
end

end
