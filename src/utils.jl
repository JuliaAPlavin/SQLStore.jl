const stmt_cache = Dict{String, SQLite.Stmt}()
function execute(db, query, args...)
    stmt = get!(stmt_cache, query) do
        DBInterface.prepare(db, query)
    end
    DBInterface.execute(stmt, args...)
end

@generated function add_prefix_to_fieldnames(nt::NamedTuple, ::Val{prefix}) where {prefix}
    spec = map(fieldnames(nt)) do k
        new_k = "$prefix$k" |> Symbol
        :( $new_k = nt.$k )
    end
    quote
        ($(spec...),)
    end
end

function merge_nosame(a::NamedTuple{na}, b::NamedTuple{nb}) where {na, nb}
    @assert isdisjoint(na, nb)
    merge(a, b)
end
