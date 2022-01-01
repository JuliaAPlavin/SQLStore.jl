module SQLStore

using DBInterface: execute
using Dates
import JSON3
using Tables: rowtable
using DataPipes

export create_table, table, update, updateonly, updatesome


function create_table(db, table_name::AbstractString, T::Type{<:NamedTuple}; constraint=nothing)
    occursin(r"^\w+$", table_name) || throw("Table name cannot contain special symbols: got $table_name")
    field_specs = map(fieldnames(T), fieldtypes(T)) do name, type
        (occursin(r"^\w+$", string(name)) && name != :_rowid_) || throw("Column name cannot contain special symbols: got $name")
        colspec(name, type)
    end
    stmt = """
    CREATE TABLE $table_name (
        $(join(field_specs, ",\n    "))

        -- CONSTRAINTS
        $(isnothing(constraint) ? "" : "," * constraint)
    )"""
    execute(db, stmt)
end

Base.@kwdef struct Table
    db
    name::AbstractString
    schema
end

function table(db, name::AbstractString)
    sql_def = first(execute(db, "select * from sqlite_schema where name = :name", (;name))).sql
    Table(; db, name, schema=parse_sql_to_schema(sql_def))
end

function parse_sql_to_schema(sql::AbstractString)
    lines = split(sql, "\n")
    
    err = "Table wasn't created by SQLStore.jl, or there is a schema parsing inconsistency"
    tabname = let line = lines[1]
        m = match(r"^CREATE TABLE (\w+) \($", lines[1])
        isnothing(m) && throw(err)
        m[1]
    end
    lines[end] == ")" || throw(err)

    types = [
        TM
        for T in [Bool, Int, Float64, String, DateTime, Dict, Any]
        for TM in (T isa UnionAll || T == Any ? [T] : [T, Union{T, Missing}])
    ]
    @p begin
        lines[2:end]
        Iterators.takewhile(!isempty(strip(_)))
        map() do line
            line = strip(line, [' ', ','])
            m = match(r"^\w+", line)
            colname = m.match
            matching_types = filter(types) do T
                colspec(colname, T) == line
            end
            isempty(matching_types) && throw("No types match definition of column $colname. " * err)
            length(matching_types) > 1 && throw("Multiple types $matching_types match definition of column $colname")
            return Symbol(colname) => (
                type=only(matching_types),
            )
        end
        NamedTuple()
    end
end


function Base.push!(tbl::Table, row::NamedTuple)
    fnames = keys(tbl.schema)
    vals = process_insert_row(row)
    execute(
        tbl.db,
        "insert into $(tbl.name) ($(join(fnames, ", "))) values ($(join(":" .* string.(fnames), ", ")))",
        vals
    )
end

function Base.length(tbl::Table)
    execute(tbl.db, "select count(*) from $(tbl.name)") |> first |> only
end

function Base.count(query, tbl::Table)
    qstr, params = query_to_sql(tbl, query)
    execute(tbl.db, "select count(*) from $(tbl.name) where $(qstr)", params) |> first |> only
end

function Base.any(query, tbl::Table)
    qstr, params = query_to_sql(tbl, query)
    any(_ -> true, execute(tbl.db, "select * from $(tbl.name) where $(qstr) limit 1", params))
end

function Base.collect(tbl::Table)
    map(execute(tbl.db, "select * from $(tbl.name)")) do r
        process_select_row(tbl.schema, r)
    end
end

function Base.filter(query, tbl::Table; limit=nothing)
    qstr, params = query_to_sql(tbl, query)
    qres = execute(tbl.db, "select * from $(tbl.name) where $(qstr) $(limit_to_sql(limit))", params)
    map(qres) do r
        process_select_row(tbl.schema, r)
    end
end

Base.first(query, tbl::Table) = filter(query, tbl; limit=1) |> only
Base.only(query, tbl::Table) = filter(query, tbl; limit=2) |> only

function Iterators.filter(query, tbl::Table)
    qstr, params = query_to_sql(tbl, query)
    qres = execute(tbl.db, "select * from $(tbl.name) where $(qstr)", params)
    Iterators.map(qres) do r
        process_select_row(tbl.schema, r)
    end
end

function update((qwhere, qset)::Pair, tbl::Table; returning=nothing)
    wstr, wparams = query_to_sql(tbl, qwhere)
    sstr, sparams = setquery_to_sql(tbl, qset)
    ret_str = isnothing(returning) ? "" : "returning $returning"
    qres = execute(tbl.db, "update $(tbl.name) set $(sstr) where $(wstr) $ret_str", merge_nosame(wparams, sparams))
end

function updateonly(queries, tbl::Table)
    qres = update(queries, tbl; returning="_rowid_") |> rowtable
    isempty(qres) && throw("No rows were updated. WHERE query: $qwhere")
    length(qres) > 1 && throw("More than one row was updated: $(length(qres)). WHERE query: $qwhere")
end

function updatesome(queries, tbl::Table)
    qres = update(queries, tbl; returning="_rowid_") |> rowtable
    isempty(qres) && throw("No rows were updated. WHERE query: $qwhere")
end


limit_to_sql(lim::Nothing) = ""
limit_to_sql(lim::Int) = "limit $lim"

query_to_sql(tbl, q::AbstractString) = q, (;)
query_to_sql(tbl, q::NamedTuple{()}) = "1", (;)  # always-true filter
query_to_sql(tbl, q::NamedTuple) = @p begin
    map(keys(q), values(q)) do k, v
        "$k = :$k"
    end
    return join(↑, " and "), process_insert_row(q)
end
query_to_sql(tbl, q::Tuple{AbstractString, Vararg}) = first(q), Base.tail(q)
query_to_sql(tbl, q::Tuple{AbstractString, NamedTuple}) = first(q), last(q)

setquery_to_sql(tbl, q::AbstractString) = q, (;)
setquery_to_sql(tbl, q::NamedTuple) = @p begin
    @aside prefix = :_SET_
    map(keys(q), values(q)) do k, v
        "$k = :$prefix$k"
    end
    return join(↑, ", "), add_prefix_to_fieldnames(process_insert_row(q), Val(prefix))
end
setquery_to_sql(tbl, q::Tuple{AbstractString, NamedTuple}) = first(q), last(q)


process_insert_row(row) = map(process_insert_field, row)
process_insert_field(x) = x
process_insert_field(x::DateTime) = Dates.format(x, dateformat"yyyy-mm-dd HH:MM:SS.sss")
process_insert_field(x::Dict) = JSON3.write(x)

process_select_row(schema, row) = map(schema, NamedTuple(row)) do sch, val
    process_select_field(sch.type, val)
end
process_select_field(_, x) = x
process_select_field(::Type{DateTime}, x) = DateTime(x, dateformat"yyyy-mm-dd HH:MM:SS.sss")
process_select_field(::Type{Dict}, x) = copy(JSON3.read(x))

function colspec(name, T::Type)
    ct = coltype(T)
    cc = colcheck(name, T)
    spec = isempty(cc) ? "$name $ct" : "$name $ct check ($cc)"
    strip(spec)
end

# specify integer type as "int", not "integer": we don't want our columns to become rowid
# this is done for more reliable updating
coltype(::Type{Bool}) = "int not null"
coltype(::Type{Int}) = "int not null"
coltype(::Type{Float64}) = "real not null"
coltype(::Type{String}) = "text not null"
coltype(::Type{DateTime}) = "text not null"
coltype(::Type{Dict}) = "text not null"
coltype(::Type{Any}) = ""
coltype(::Type{Union{T, Missing}}) where {T} = replace(coltype(T), " not null" => "")

colcheck(name, ::Type{Bool}) = "$name in (0, 1)"
colcheck(name, ::Type{Int}) = "typeof($name) = 'integer'"
colcheck(name, ::Type{Float64}) = "typeof($name) = 'real'"
colcheck(name, ::Type{String}) = "typeof($name) = 'text'"
colcheck(name, ::Type{DateTime}) = "typeof($name) = 'text' and $name == strftime('%Y-%m-%d %H:%M:%f', $name)"
colcheck(name, ::Type{Dict}) = "json_valid($name)"
colcheck(name, ::Type{Any}) = ""
colcheck(name, ::Type{Union{T, Missing}}) where {T} = "($(colcheck(name, T))) or $name is null"


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

end
