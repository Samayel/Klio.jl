using Reduce

_calc_reduce_initialized = false

function calc(req::OutgoingWebhookRequest)::OutgoingWebhookResponse
    global _calc_reduce_initialized
    if !_calc_reduce_initialized
        rcall("load_package RESET")
        rcall("load_package RLFI")
        rcall("1+1")
        _calc_reduce_initialized = true
    end
    question = replace(req.text, "!calc " => "")
    try rcall("RESETREDUCE") catch; end
    answer = rcall(question, :latex) |> string |> chomp
    answer = replace(answer, "\\begin{displaymath}" => "")
    answer = replace(answer, "\\end{displaymath}" => "")
    return OutgoingWebhookResponse("```latex\n" * answer * "\n```")
end
