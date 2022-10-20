#!/usr/bin/env julia

using Klio
using Sockets

Klio.settings.server_host = @ip_str "0.0.0.0"

Klio.run()
