module Calc

using ..Mattermost

reduce_initialized = false

function calc(req)
    startswith(req.text, "!calc --reduce ") && return req.text |> rcalc_lazy
    req.text |> mcalc_lazy
end

function rcalc_lazy(question)
    @eval begin
        using Reduce
        rcalc($question)
    end
end

function rcalc(question)
    question = replace(question, "!calc --reduce " => "")
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

    try rcall("RESETREDUCE") catch; end

    try
        answer = rcall(question, :latex) |> string
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

    try
        answer = mcall(question) |> string
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
