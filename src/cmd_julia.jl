module Julia

using ..Mattermost

using Latexify
using Random

function inject_module(request)
    parsed = "begin " * request * " end" |> Meta.parse

    func_expr = :(function execute() end)
    func_body = func_expr.args[2]
    func_body.args = [e for e in parsed.args if !isa(e, Expr) || e.head != :using]

    module_symbol = Random.randstring('A':'Z', 20) |> Symbol
    module_expr = :(module $module_symbol end)
    module_body = module_expr.args[3]
    module_body.args = [e for e in parsed.args if isa(e, Expr) && e.head == :using]
    if isempty(module_body.args)
        push!(module_body.args, :(using Nemo))
    end
    push!(module_body.args, func_expr)

    module_expr |> Base.eval

    return module_symbol
end

function render(answer)
    if !occursin('^', answer) && !occursin('_', answer) && !occursin('\\', answer)
        return "`$answer`"
    end

    try
        response = replace(answer, "//" => "/") |> latexify
        response = replace(response, r"^[^$]*[$]+" => "```latex\n")
        return     replace(response, r"[$]+[^$]*$" => "\n```")
    catch ex
        return "`$answer`"
    end
end

function julia(req)
    request = replace(req.text, "!julia " => "")
    request = strip(request, ['`', ' '])

    local output
    try
        module_symbol = inject_module(request)
        answer = @eval Base $module_symbol.execute() |> string
        output = answer |> render
    catch ex
        output = "```\n" * sprint(showerror, ex) * "\n```"
    end

    return OutgoingWebhookResponse(output)
end

end
