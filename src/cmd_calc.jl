module Calc

using ..Mattermost

reduce_initialized = false

function calc(req)
    startswith(req.text, "!calc --wolfram ") && return req.text |> wcalc_lazy
    startswith(req.text, "!calc --reduce ")  && return req.text |> rcalc_lazy
    startswith(req.text, "!calc --maxima ")  && return req.text |> mcalc_lazy
    req.text |> wcalc_lazy
end

function wcalc_lazy(question)
    @eval begin
        using MathLink
        wcalc($question)
    end
end

function wcalc(question)
    question = replace(question, "!calc --wolfram " => "")
    question = replace(question, "!calc " => "")
    question = strip(question, ['`', ' '])

    question = question * " // TeXForm // ToString"

    try "Remove[\"Global`*\"]" |> MathLink.parseexpr |> weval catch; end

    local answer
    try
        answer = question |> MathLink.parseexpr |> weval |> string
    catch ex
        if isa(ex, MathLink.MathLinkError)
            return OutgoingWebhookResponse("```\n" * string(typeof(ex)) * "\n" * ex.msg * "```")
        else
            rethrow
        end
    end

    if occursin('^', answer) || occursin('_', answer) || occursin('\\', answer) || occursin('\n', answer)
        return OutgoingWebhookResponse("```latex\n" * answer * "\n```")
    else
        return OutgoingWebhookResponse("`" * answer * "`")
    end
end

function rcalc_lazy(question)
    @eval begin
        using Reduce
        rcalc($question)
    end
end

function rcalc(question)
    question = replace(question, "!calc --reduce " => "")
    question = replace(question, "!calc " => "")
    question = strip(question, ['`', ' '])

    if occursin(r"(in|out)\s+"i, question)
        throw(ReduceError("Forbidden"))
    end

    global reduce_initialized
    if !reduce_initialized
        rcall("load_package RESET")
        rcall("load_package RLFI")
        reduce_initialized = true
    end

#   try rcall("RESETREDUCE") catch; end

    local answer
    try
        answer = rcall(String(question), :latex) |> string
    catch ex
        if isa(ex, ReduceError)
            return OutgoingWebhookResponse("```\n" * string(typeof(ex)) * ex.errstr * "```")
        else
            rethrow
        end
    end

    answer = replace(answer, "\\begin{displaymath}" => "")
    answer = replace(answer, "\\end{displaymath}" => "")
    answer = strip(answer)

    if occursin('^', answer) || occursin('_', answer) || occursin('\\', answer) || occursin('\n', answer)
        return OutgoingWebhookResponse("```latex\n" * answer * "\n```")
    else
        return OutgoingWebhookResponse("`" * answer * "`")
    end
end

function mcalc_lazy(question)
    @eval begin
        using Maxima
        mcalc($question)
    end
end

function mcalc(question)
    question = replace(question, "!calc --maxima " => "")
    question = replace(question, "!calc " => "")
    question = strip(question, ['`', ' '])

    if occursin(r"(batch[a-z_]*|file[a-z_]*|load[a-z_]+|pathname[a-z_]*|save|stringout|with_stdout|[a-z_]*file)\s*\("i, question)
        throw(MaximaError("Forbidden"))
    end

    try
        mcall("kill (all)")
        mcall("reset ()")
        mcall("display2d: false")
    catch
    end

    local answer
    try
        answer = mcall(String(question)) |> string
    catch ex
        if isa(ex, MaximaError) || isa(ex, MaximaSyntaxError)
            return OutgoingWebhookResponse("```\n" * string(typeof(ex)) * ex.errstr * "```")
        else
            rethrow
        end
    end

    if startswith(answer, "\$\$")
        answer = replace(answer, r"^[^$]*[$]{2}" => "")
        answer = replace(answer, r"[$]{2}[^$]*$" => "")
        return OutgoingWebhookResponse("```latex\n" * answer * "\n```")
    else
        return OutgoingWebhookResponse("`" * answer * "`")
    end
end

end
