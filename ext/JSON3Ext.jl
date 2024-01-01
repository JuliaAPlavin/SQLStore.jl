module JSON3Ext

import SQLStore: process_insert_field, process_select_field, SQLStore
import JSON3

process_insert_field(::Type{SQLStore.JSON3}, x) = JSON3.write(x)
process_select_field(::Type{SQLStore.JSON3}, x) = _json_materialize(JSON3.read(x))

# https://github.com/quinnj/JSON3.jl/pull/220:
_json_materialize(x::String) = x
_json_materialize(x) = copy(x)

end
