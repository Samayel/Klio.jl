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
