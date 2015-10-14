

import JSON
using Mux


# Data Store:
# Models
# - Params + Data
#    - names
#    - defaults
# - Execution
#   - Param Set
#     - Traces


# Get a JSON list of the models available
function get_models(req)

end

# Get a JSON list of the traces available
function get_traces(req)

end

function run_model(req)

end

function get_static_file(req)
    static_path = "$(dirname(@__FILE__))/static/$(req[:params][:file])"
    f = open(static_path)
    contents = readall(f)
    close(f)
    return contents
end

function get_index(req)
    req[:params][:file] = "index.html"
    return get_static_file(req)
end

function load_ds()

end

function start_server(base_dir :: String)

    @app ui_server = (
        Mux.defaults,
        page(get_index),
        page("/static/:file", get_static_file),
        page("/models", get_models),
        page("/traces", get_traces),
        page("/run-model", run_model),
        Mux.notfound()
    )

    serve(ui_server)
end

function start_server()
    start_server(pwd())
end


println(@__FILE__)
