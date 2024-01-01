# Dict: (db, query) => statement
const stmt_cache = Dict{Tuple{Any, String}, Any}()
const _lock = ReentrantLock()
function execute(db, query, args...)
    lock(_lock) do
        stmt = get!(stmt_cache, (db, query)) do
            DBInterface.prepare(db, query)
        end
        DBInterface.execute(stmt, args...)
    end
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
