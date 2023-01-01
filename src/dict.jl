abstract type SQLAbstractDict{K, V} <: AbstractDict{K, V} end

struct SQLDict{K, V, TKC, TVC} <: SQLAbstractDict{K, V}
    tbl::Table
    columns_key::TKC
    columns_value::TVC
end

struct SQLDictON{K, V, TKC, TVC} <: SQLAbstractDict{K, V}
    tbl::Table
    columns_key::TKC
    columns_value::TVC
end


for T in [SQLDict, SQLDictON]
    @eval function $T{K, V}(tbl::TableNonexistent) where {K, V}
        tbl = create_table(tbl.db, tbl.name, @NamedTuple{k::K, v::V}; constraints="PRIMARY KEY (k)")
        $T{actual_julia_type(K), actual_julia_type(V), Symbol, Symbol}(tbl, :k, :v)
    end

    @eval function $T{K, V}(tbl::Table) where {K, V}
        # ensure compatible:
        create_table(tbl.db, tbl.name, @NamedTuple{k::K, v::V}; constraints="PRIMARY KEY (k)", keep_compatible=true)
        $T{actual_julia_type(K), actual_julia_type(V), Symbol, Symbol}(tbl, :k, :v)
    end
end

Base.get(dct::SQLAbstractDict, key, default) = get(Returns(default), dct, key)


function Base.get(default::Function, dct::SQLDict{K}, key::K) where {K}
    rows = filter(wrap_value(dct.columns_key, key), dct.tbl, Cols(dct.columns_value); limit=2)
    if length(rows) == 0
        return default()
    elseif length(rows) == 1
        return unwrap_value(dct.columns_value, only(rows))
    elseif length(rows) >= 2
        error("Unexpected: multiple rows match key $(dct.columns_key) = $key")
    end
end

function Base.setindex!(dct::SQLDict{K, V}, val::V, key::K) where {K, V}
    badnames = intersect(union_cols(dct.columns_key), dct.tbl.reserialize_mismatches)
    isempty(badnames) || error("Trying to query by columns that don't match their re-serialization: $(join(dct.tbl.name .* "." .* string.(badnames), ", "))")

    rowvals = process_insert_row(dct.tbl.schema, merge(wrap_value(dct.columns_key, key), wrap_value(dct.columns_value, val)))
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



function Base.get(default::Function, dct::SQLDictON{K}, key::K) where {K}
    keyrows = @p collect(dct.tbl, Cols(Rowid(), dct.columns_key)) |> filter(isequal(key, _[dct.columns_key]))
    if length(keyrows) == 0
        return default()
    elseif length(keyrows) == 1
        row = only((;only(keyrows)._rowid_), dct.tbl, Cols(dct.columns_value))
        return unwrap_value(dct.columns_value, row)
    elseif length(keyrows) >= 2
        error("Unexpected: multiple rows match key $(dct.columns_key) = $key")
    end
end

function Base.setindex!(dct::SQLDictON{K, V}, val::V, key::K) where {K, V}
    keyrows = @p collect(dct.tbl, Cols(Rowid(), dct.columns_key)) |> filter(isequal(key, _[dct.columns_key]))
    if length(keyrows) == 0
        push!(dct.tbl, merge(wrap_value(dct.columns_key, key), wrap_value(dct.columns_value, val)))
    elseif length(keyrows) == 1
        updateonly!((;only(keyrows)._rowid_) => wrap_value(dct.columns_value, val), dct.tbl)
    elseif length(keyrows) >= 2
        error("Unexpected: multiple rows match key $(dct.columns_key) = $key")
    end
    return dct
end

function Base.delete!(dct::SQLDictON{K, V}, key::K) where {K, V}
    keyrows = @p collect(dct.tbl, Cols(Rowid(), dct.columns_key)) |> filter(isequal(key, _[dct.columns_key]))
    if length(keyrows) == 0
    elseif length(keyrows) == 1
        deleteonly!((;only(keyrows)._rowid_), dct.tbl)
    elseif length(keyrows) >= 2
        error("Unexpected: multiple rows match key $(dct.columns_key) = $key")
    end
    return dct
end

function Base.pop!(dct::SQLDictON{K, V}, key::K, default) where {K, V}
    keyrows = @p collect(dct.tbl, Cols(Rowid(), dct.columns_key)) |> filter(isequal(key, _[dct.columns_key]))
    if length(keyrows) == 0
        return default
    elseif length(keyrows) == 1
        row = only((;only(keyrows)._rowid_), dct.tbl, Cols(dct.columns_value))
        deleteonly!((;only(keyrows)._rowid_), dct.tbl)
        return unwrap_value(dct.columns_value, row)
    elseif length(keyrows) >= 2
        error("Unexpected: multiple rows match key $(dct.columns_key) = $key")
    end
end


function Base.pop!(dct::SQLAbstractDict, key)
    sentinel = :fjdkslfdslkfsf
    res = pop!(dct, key, sentinel)
    res === sentinel ? throw(KeyError(key)) : res
end

function Base.empty!(dct::SQLAbstractDict)
    delete!((;), dct.tbl)
    dct
end

function Base.iterate(dct::SQLAbstractDict, (pairs_vec, state))
    x = iterate(pairs_vec, state)
    isnothing(x) && return x
    (res, state) = x
    return (res, (pairs_vec, state))
end
function Base.iterate(dct::SQLAbstractDict)
    pairs_vec =
        @p collect(dct.tbl, Cols(union_cols(dct.columns_key, dct.columns_value)...)) |>
        map(_[dct.columns_key] => _[dct.columns_value])
    x = iterate(pairs_vec)
    isnothing(x) && return x
    (res, state) = x
    return (res, (pairs_vec, state))
end

Base.length(dct::SQLAbstractDict) = length(dct.tbl)
Base.isempty(dct::SQLAbstractDict) = isempty(dct.tbl)

wrap_value(keycol::Symbol, key) = NamedTuple{(keycol,)}((key,))
unwrap_value(valcol::Symbol, val::NamedTuple) = (@assert keys(val) == (valcol,); only(val))
union_cols(a::Symbol) = (a,)
union_cols(a::Symbol, b::Symbol) = (a, b)
