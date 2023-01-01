struct SQLDict{K, V, TKC, TVC} <: AbstractDict{K, V}
    tbl::Table
    columns_key::TKC
    columns_value::TVC
end

SQLDict(tbl::Table, columns_key, columns_value) = SQLDict{Any, Any, typeof(columns_key), typeof(columns_value)}(tbl, columns_key, columns_value)

function SQLDict{K, V}(tbl::TableNonexistent) where {K, V}
    tbl = create_table(tbl.db, tbl.name, @NamedTuple{k::K, v::V}; constraints="PRIMARY KEY (k)")
    SQLDict{K, V, Symbol, Symbol}(tbl, :k, :v)
end

function SQLDict{K, V}(tbl::Table) where {K, V}
    # ensure compatible:
    create_table(tbl.db, tbl.name, @NamedTuple{k::K, v::V}; constraints="PRIMARY KEY (k)", keep_compatible=true)
    SQLDict{K, V, Symbol, Symbol}(tbl, :k, :v)
end

function Base.get(dct::SQLDict, key, default)
    rows = filter(wrap_value(dct.columns_key, key), dct.tbl, Cols(dct.columns_value); limit=2)
    if length(rows) == 0
        return default
    elseif length(rows) == 1
        return unwrap_value(dct.columns_value, only(rows))
    elseif length(rows) >= 2
        error("Unexpected: multiple rows match key $(dct.columns_key) = $key")
    end
end

function Base.setindex!(dct::SQLDict{K, V}, val::V, key::K) where {K, V}
    rowvals = process_insert_row(merge(wrap_value(dct.columns_key, key), wrap_value(dct.columns_value, val)))
    allcols = union_cols(dct.columns_key, dct.columns_value)
    execute(
        dct.tbl.db,
        """
        insert or replace into $(dct.tbl.name)
        ($(join(allcols, ", ")))
        values ($(join(":" .* string.(allcols), ", ")))
        """,
        rowvals
    )
    return dct
end

function Base.delete!(dct::SQLDict{K, V}, key::K) where {K, V}
    delete!(wrap_value(dct.columns_key, key), dct.tbl)
    return dct
end

function Base.pop!(dct::SQLDict{K, V}, key::K) where {K, V}
    rows = delete!(wrap_value(dct.columns_key, key), dct.tbl; returning=dct.columns_value) |> rowtable
    if length(rows) == 0
        throw(KeyError(key))
    elseif length(rows) == 1
        return unwrap_value(dct.columns_value, only(rows))
    elseif length(rows) >= 2
        error("Unexpected: multiple rows match key $(dct.columns_key) = $key")
    end
end

function Base.pop!(dct::SQLDict{K, V}, key::K, default) where {K, V}
    rows = delete!(wrap_value(dct.columns_key, key), dct.tbl; returning=dct.columns_value) |> rowtable
    if length(rows) == 0
        return default
    elseif length(rows) == 1
        return unwrap_value(dct.columns_value, only(rows))
    elseif length(rows) >= 2
        error("Unexpected: multiple rows match key $(dct.columns_key) = $key")
    end
end

function Base.empty!(dct::SQLDict)
    delete!((;), dct.tbl)
    dct
end

function Base.iterate(dct::SQLDict, (pairs_vec, state))
    x = iterate(pairs_vec, state)
    isnothing(x) && return x
    (res, state) = x
    return (res, (pairs_vec, state))
end
function Base.iterate(dct::SQLDict)
    pairs_vec =
        @p collect(dct.tbl, Cols(union_cols(dct.columns_key, dct.columns_value)...)) |>
        map(_[dct.columns_key] => _[dct.columns_value])
    x = iterate(pairs_vec)
    isnothing(x) && return x
    (res, state) = x
    return (res, (pairs_vec, state))
end

Base.length(dct::SQLDict) = length(dct.tbl)
Base.isempty(dct::SQLDict) = isempty(dct.tbl)

wrap_value(keycol::Symbol, key) = NamedTuple{(keycol,)}((key,))
unwrap_value(valcol::Symbol, val::NamedTuple) = (@assert keys(val) == (valcol,); only(val))
union_cols(a::Symbol, b::Symbol) = (a, b)
