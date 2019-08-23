using HTTP
using JSON2

import HTTP: handle

"""
    JSONHandler{T,F} <: HTTP.RequestHandler

HTTP.RequestHandler specialization holding a function of type `F`. The wrapped
function receives the payload of type `T`, which is parsed from the HTTP request
body in JSON format. The function's return value will be converted to JSON and
written to the HTTP response body
"""
struct JSONHandler{T,F} <: HTTP.RequestHandler
    func::F # func(reqPayload::T)
end

"""
    JSONHandler{T}(func::F) where {T, F}

Outer constructor for JSONHandler, allowing `T` to be specified as type
parameter while inferring `F` from `func`.
"""
JSONHandler{T}(func::F) where {T, F} = JSONHandler{T, F}(func)

"""
    HTTP.handle(h::JSONHandler{T}, ::HTTP.Request) where {T}

Overloaded method of `HTTP.handle` for `JSONHandler`. Parses the request body
into an instance of `T` and passes it to `h`. The return value of `h` is
converted to JSON and written to the response body.

Registering a `JSONHandler` with `HTTP.@register` will make the `HTTP` module
call this method for a matching request.
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
