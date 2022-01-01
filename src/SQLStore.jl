module SQLStore

using DBInterface: execute
using Dates
import JSON3
import Tables
using Tables: rowtable, schema, columnnames
using DataPipes
import DataAPI: All, ncol, nrow

export
    create_table, table,
    update!, updateonly!, updatesome!,
    deleteonly!, deletesome!,
    WithRowid, WithoutRowid, Rowid,
    sample,
    schema, columnnames

function create_table(db, table_name::AbstractString, T::Type{<:NamedTuple}; constraint=nothing)
    occursin(r"^\w+$", table_name) || throw("Table name cannot contain special symbols: got $table_name")
    field_specs = map(fieldnames(T), fieldtypes(T)) do name, type
        (occursin(r"^\w+$", string(name)) && name != ROWID_NAME) || throw("Column name cannot contain special symbols: got $name")
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

Tables.schema(tbl::Table) = Tables.Schema(keys(tbl.schema), @p tbl.schema |> map(_.type))
Tables.columnnames(tbl::Table) = keys(tbl.schema)

function table(db, name::AbstractString)
    sql_def = @p execute(db, "select * from sqlite_schema where name = :name", (;name)) |> rowtable |> only |> (↑).sql
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
        [
            TM
            for T in [Bool, Int, Float64, String, DateTime]
            for TM in [T, Union{T, Missing}]
        ];
        # UnionAlls don't work with missing for now:
        Dict;
        # don't need missing:
        Any; Rowid;
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
    vals = process_insert_row(row)
    fnames = keys(vals)
    if isempty(vals)
        execute(tbl.db, "insert into $(tbl.name) default values")
    else
        execute(
            tbl.db,
            "insert into $(tbl.name) ($(join(fnames, ", "))) values ($(join(":" .* string.(fnames), ", ")))",
            vals
        )
    end
end

ncol(tbl::Table) = length(tbl.schema)
nrow(tbl::Table) = length(tbl)
function Base.length(tbl::Table)
    execute(tbl.db, "select count(*) from $(tbl.name)") |> rowtable |> only |> only
end

function Base.count(query, tbl::Table)
    qstr, params = query_to_sql(tbl, query)
    execute(tbl.db, "select count(*) from $(tbl.name) where $(qstr)", params) |> rowtable |> only |> only
end

function Base.any(query, tbl::Table)
    qstr, params = query_to_sql(tbl, query)
    !isempty(execute(tbl.db, "select $ROWID_NAME from $(tbl.name) where $(qstr) limit 1", params) |> rowtable)
end


const ROWID_NAME = :_rowid_
abstract type RowidSpec end
struct WithRowid <: RowidSpec end
struct WithoutRowid <: RowidSpec end
rowid_select_sql(::WithoutRowid) = ""
rowid_select_sql(::WithRowid) = "$ROWID_NAME as $ROWID_NAME,"


function Base.collect(tbl::Table, rowid::RowidSpec=WithoutRowid())
    map(execute(tbl.db, "select $(rowid_select_sql(rowid)) * from $(tbl.name)")) do r
        process_select_row(tbl.schema, r)
    end
end

function Base.filter(query, tbl::Table, rowid::RowidSpec=WithoutRowid(); limit=nothing)
    qstr, params = query_to_sql(tbl, query)
    qres = execute(tbl.db, "select $(rowid_select_sql(rowid)) * from $(tbl.name) where $(qstr) $(limit_to_sql(limit))", params)
    map(qres) do r
        process_select_row(tbl.schema, r)
    end
end

Base.first(query, tbl::Table, rowid::RowidSpec=WithoutRowid()) = filter(query, tbl, rowid; limit=1) |> only
Base.only(query, tbl::Table, rowid::RowidSpec=WithoutRowid()) = filter(query, tbl, rowid; limit=2) |> only

function sample(query, tbl::Table, n::Int, rowid::RowidSpec=WithoutRowid(); replace=true)
    if n > 1 && replace
        throw(ArgumentError("Sampling multiple elements with replacement is not supported"))
    end
    qstr, params = query_to_sql(tbl, query)
    qres = execute(tbl.db, "select $(rowid_select_sql(rowid)) * from $(tbl.name) where $(qstr) order by random() limit $n", params)
    res = map(qres) do r
        process_select_row(tbl.schema, r)
    end
    length(res) < n && error("Cannot draw more samples without replacement")
    return res
end

sample(tbl::Table, n::Int, rowid::RowidSpec=WithoutRowid(); replace=true) = sample((;), tbl, n, rowid; replace)
Base.rand(query, tbl::Table, rowid::RowidSpec=WithoutRowid()) = sample(query, tbl, 1, rowid) |> only
Base.rand(tbl::Table, rowid::RowidSpec=WithoutRowid()) = rand((;), tbl, rowid)

## Query doesn't get closed - database may remain locked
# function Iterators.filter(query, tbl::Table, rowid::RowidSpec=WithoutRowid())
#     qstr, params = query_to_sql(tbl, query)
#     qres = execute(tbl.db, "select $(rowid_select_sql(rowid)) * from $(tbl.name) where $(qstr)", params)
#     Iterators.map(qres) do r
#         process_select_row(tbl.schema, r)
#     end
# end

function update!((qwhere, qset)::Pair, tbl::Table; returning=nothing)
    wstr, wparams = query_to_sql(tbl, qwhere)
    sstr, sparams = setquery_to_sql(tbl, qset)
    ret_str = isnothing(returning) ? "" : "returning $returning"
    execute(tbl.db, "update $(tbl.name) set $(sstr) where $(wstr) $ret_str", merge_nosame(wparams, sparams))
end

function updateonly!(queries, tbl::Table)
    qres = update!(queries, tbl; returning=ROWID_NAME) |> rowtable
    isempty(qres) && throw(ArgumentError("No rows were updated. Query: $queries"))
    length(qres) > 1 && throw(ArgumentError("More than one row was updated: $(length(qres)). Query: $queries"))
end

function updatesome!(queries, tbl::Table)
    qres = update!(queries, tbl; returning=ROWID_NAME) |> rowtable
    isempty(qres) && throw(ArgumentError("No rows were updated. Query: $queries"))
end


function Base.delete!(query, tbl::Table; returning=nothing)
    str, params = query_to_sql(tbl, query)
    ret_str = isnothing(returning) ? "" : "returning $returning"
    execute(tbl.db, "delete from $(tbl.name) where $(str) $ret_str", params)
end

function deleteonly!(query, tbl::Table)
    qres = delete!(query, tbl; returning=ROWID_NAME) |> rowtable
    isempty(qres) && throw(ArgumentError("No rows were deleted. WHERE query: $query"))
    length(qres) > 1 && throw(ArgumentError("More than one row was deleted: $(length(qres)). WHERE query: $query"))
end

function deletesome!(query, tbl::Table)
    qres = delete!(query, tbl; returning=ROWID_NAME) |> rowtable
    isempty(qres) && throw(ArgumentError("No rows were deleted. WHERE query: $query"))
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

struct Rowid end

process_insert_row(row) = map(process_insert_field, row)
process_insert_field(x) = x
process_insert_field(x::DateTime) = Dates.format(x, dateformat"yyyy-mm-dd HH:MM:SS.sss")
process_insert_field(x::Dict) = JSON3.write(x)
process_insert_field(x::Vector) = JSON3.write(x)

process_select_row(schema, row) = process_select_row(schema, NamedTuple(row))
function process_select_row(schema, row::NamedTuple{names}) where {names}
    res = map(schema, Base.structdiff(row, NamedTuple{(ROWID_NAME,)})) do sch, val
        process_select_field(sch.type, val)
    end
    return if first(names) == ROWID_NAME
        merge(NamedTuple{(ROWID_NAME,)}(row[ROWID_NAME]), res)
    else
        res
    end
end
process_select_field(T::Type, x) = x::T
process_select_field(::Type{Rowid}, x) = x::Int
process_select_field(::Type{DateTime}, x) = DateTime(x, dateformat"yyyy-mm-dd HH:MM:SS.sss")
process_select_field(::Type{Dict}, x) = copy(JSON3.read(x))

colspec(name, ::Type{Rowid}) = "$name integer primary key"
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
coltype(::Type{Vector}) = "text not null"
coltype(::Type{Any}) = ""
coltype(::Type{Union{T, Missing}}) where {T} = replace(coltype(T), " not null" => "")

colcheck(name, ::Type{Bool}) = "$name in (0, 1)"
colcheck(name, ::Type{Int}) = "typeof($name) = 'integer'"
colcheck(name, ::Type{Float64}) = "typeof($name) = 'real'"
colcheck(name, ::Type{String}) = "typeof($name) = 'text'"
colcheck(name, ::Type{DateTime}) = "typeof($name) = 'text' and $name == strftime('%Y-%m-%d %H:%M:%f', $name)"
colcheck(name, ::Type{Dict}) = "json_valid($name)"
colcheck(name, ::Type{Vector}) = "json_valid($name)"
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
