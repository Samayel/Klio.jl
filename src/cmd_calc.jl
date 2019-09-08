module Calc

using Reduce

using ..Mattermost

reduce_initialized = false

function calc(req::OutgoingWebhookRequest)::OutgoingWebhookResponse
    global reduce_initialized
    if !reduce_initialized
        rcall("load_package RESET")
        rcall("load_package RLFI")
        rcall("1+1")
        reduce_initialized = true
    end
    question = replace(req.text, "!calc " => "")
    try rcall("RESETREDUCE") catch; end
    answer = rcall(question, :latex) |> string |> chomp
    answer = replace(answer, "\\begin{displaymath}" => "")
    answer = replace(answer, "\\end{displaymath}" => "")
    return OutgoingWebhookResponse("```latex\n" * answer * "\n```")
end

end
