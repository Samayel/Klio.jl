module MattermostHandler

using HTTP
using JSON2

using ..MattermostTypes

"""
    JSONHandler{T,F}

The wrapped function receives the payload of type `T`, which is parsed from the
HTTP request body in JSON format. The function's return value will be converted
to JSON and written to the HTTP response body
"""
struct JSONHandler{T,F}
    func::F # func(reqPayload::T)
end

"""
    JSONHandler{T}(func::F) where {T, F}

Outer constructor for JSONHandler, inferring `T` and `F` from parameters.
"""
JSONHandler(::Type{T}, func::F) where {T, F} = JSONHandler{T, F}(func)

"""
    handle(h::JSONHandler{T}, ::HTTP.Request) where {T}

Parses the request body into an instance of `T` and passes it to `h`.
The return value of `h` is converted to JSON and written to the response body.
"""
function handle(h::JSONHandler{T}, req::HTTP.Request) where {T}
    res = req.response

    local reqPayload
    try
        reqPayload = JSON2.read(IOBuffer(HTTP.payload(req)), T)
    catch e
        # JSON parsing failed, return "bad request"
        res.status = 400
        return res
    end

    resPayload = h.func(reqPayload)
    HTTP.setheader(res, "Content-Type" => "application/json")
    JSON2.write(IOBuffer(res.body, write = true), resPayload)
    return res
end

wrap(fn) = req -> handle(JSONHandler(OutgoingWebhookRequest, fn), req)

end
