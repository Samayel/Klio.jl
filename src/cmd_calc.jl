module Calc

using Maxima
using Reduce

using ..Mattermost

reduce_initialized = false

function calc(req)
    startswith(req.text, "!calc --maxima ") && return mcalc(replace(req.text, "!calc --maxima " => ""))
    startswith(req.text, "!calc --reduce ") && return rcalc(replace(req.text, "!calc --reduce " => ""))
    mcalc(replace(req.text, "!calc " => ""))
end

function rcalc(question)
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
    answer = rcall(question, :latex)
    answer = replace(answer, "\\begin{displaymath}" => "")
    answer = replace(answer, "\\end{displaymath}" => "")
    answer = strip(answer)

    if occursin('^', answer) || occursin('_', answer) || occursin('\\', answer) || occursin('\n', answer)
        return OutgoingWebhookResponse("```latex\n" * answer * "\n```")
    else
        return OutgoingWebhookResponse("`" * answer * "`")
    end
end

function mcalc(question)
    if occursin(r"(batch[a-z_]*|file[a-z_]*|load[a-z_]*|pathname[a-z_]*|save|stringout|with_stdout|[a-z_]*file)\s*\("i, question)
        throw(MaximaError("Forbidden"))
    end

    try
        mcall("kill (all)")
        mcall("reset ()")
        mcall("display2d: false")
    catch
    end
    answer = mcall(question)

    return OutgoingWebhookResponse("`" * answer * "`")
end

end
