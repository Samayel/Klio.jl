module Klio

using Dates
using Genie

import Genie.Router: route, POST
import Genie.Renderer: json

run() = begin
    Genie.config.run_as_server = true

    route("/time", method = POST) do
        Dict(:response_type => "in_channel", :text => Dates.now(Dates.UTC)) |> json
    end

    Genie.startup()
end

end # module
