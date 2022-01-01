module SQLStore

using DBInterface: execute, executemany
using Dates
import JSON3
import Tables
using Tables: rowtable, schema, columnnames
using DataPipes
using InvertedIndices: Not
import DataAPI: All, Cols, ncol, nrow
import SQLite

export
    SQLite,
    create_table, table,
    update!, updateonly!, updatesome!,
    deleteonly!, deletesome!,
    WithRowid, Rowid,
    sample,
    Not, All, Cols, ncol, nrow,
    schema, columnnames


const SUPPORTED_TYPES_DOC = """
Supported types:
- `Int`, `Float64`, `String` are directly stored as corresponding SQL types.
- `Bool`s stored as `0` and `1` `INTEGER`s.
- `DateTime`s are stored as `TEXT` with the `'%Y-%m-%d %H:%M:%f'` format.
- `Dict`s and `Vector`s get translated to their `JSON` representations.
- Any type can be combined with `Missing` as in `Union{Int, Missing}`. This allows `NULL`s in the corresponding column.
"""

""" `create_table(db, name, T::Type{NamedTuple}; [constraints])`

Create a table with `name` in the database `db` with column specifications derived from the type `T`.
Table constraints can be specified by the `constraints` argument.

$SUPPORTED_TYPES_DOC
"""
function create_table(db, table_name::AbstractString, T::Type{<:NamedTuple}; constraints=nothing)
    occursin(r"^\w+$", table_name) || throw("Table name cannot contain special symbols: got $table_name")
    field_specs = map(fieldnames(T), fieldtypes(T)) do name, type
        (occursin(r"^\w+$", string(name)) && name != ROWID_NAME) || throw("Column name cannot contain special symbols: got $name")
        colspec(name, type)
    end
    stmt = """
    CREATE TABLE $table_name (
        $(join(field_specs, ",\n    "))

        -- CONSTRAINTS
        $(isnothing(constraints) ? "" : "," * constraints)
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

""" Obtain the `SQLStore.Table` object corresponding to the table `name` in database `db`.

The returned object supports:
- `SELECT`ing rows with `collect`, `filter`, `first`, `only`. Random row selection: `sample`, `rand`.
- `UPDATE`ing rows with `update!`, `updateonly!`, `updatesome!`.
- `DELETE`ing rows with `delete!`, `deleteonly!`, `deletesome!`.
- `INSERT`ing rows with `push!`, `append!`.
- Retrieving metadata with `schema`, `columnnames`, `ncol`.
- Other: `nrow`, `length`, `count`, `any`.
"""
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

""" `push!(tbl::Table, row::NamedTuple)`

Insert the `row` to `tbl`. Field values are converted to SQL types.
"""
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

function Base.append!(tbl::Table, rows)
    fnames = keys(rows[1])
    @assert all(r -> keys(r) == fnames, rows)
    stmt = DBInterface.prepare(db, "INSERT INTO tmp VALUES(?, ?, ?)")

    executemany(
        tbl.db,
        "insert into $(tbl.name) ($(join(fnames, ", "))) values ($(join(":" .* string.(fnames), ", ")))",
        map(process_insert_row, rows),
    )
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

""" `Rowid()` has two uses in `SQLStore`.
- In `create_table()`: specify that a field is an `SQLite` `rowid`, that is `integer primary key`.
- In select column definitions: specify that the table `rowid` should explicitly be included in the results. The returned rowid field is named `$ROWID_NAME`.
"""
struct Rowid end

# for backwards compatibility - WithRowid was used in SQLStore before
abstract type RowidSpec end
struct WithRowid <: RowidSpec end

const COL_NAME_TYPE = Union{Symbol, String}
const COL_NAMES_TYPE = Union{
    NTuple{N, Symbol} where {N},
    NTuple{N, String} where {N},
    Vector{Symbol},
    Vector{String},
}
default_select(_) = All()
select2sql(tbl, s::Cols) = join((select2sql(tbl, ss) for ss in s.cols), ", ")
select2sql(tbl, s::COL_NAME_TYPE) = s
select2sql(tbl, s::Rowid) = "$ROWID_NAME as $ROWID_NAME"
select2sql(tbl, s::All) = (@assert isempty(s.cols); "*")
select2sql(tbl, s::WithRowid) = "$ROWID_NAME as $ROWID_NAME, *"  # backwards compatibility
select2sql(tbl, s::Not{<:COL_NAMES_TYPE}) = select2sql(tbl, Cols(filter(∉(s.skip), schema(tbl).names)...))
select2sql(tbl, s::Not{<:COL_NAME_TYPE}) = select2sql(tbl, Not((s.skip,)))

const SELECT_QUERY_DOC = """
Each row corresponds to a `NamedTuple`. Fields are converted according to the table `schema`, see `create_table` for details.

The optional `select` argument specifies fields to return, in one of the following ways.
- `All()`, the default: select all columns.
- A `Symbol`: select a single column by name.
- `Rowid()`: select the SQLite rowid column, named $ROWID_NAME in the results.
- `Cols(...)`: multiple columns, each defined as above.
- `Not(...)`: all columns excluding those listed in `Not`.
"""
const WHERE_QUERY_DOC = """
The filtering `query` corresponds to the SQL `WHERE` clause. It can be specified in one of the following forms:
- `NamedTuple`: specified fields are matched against corresponding table columns, combined with `AND`. Values are converted to corresponding SQL types, see `create_table` for details.
- `String`: kept as-is.
- Tuple `(String, args...)`: the `String` is passed to `WHERE` as-is, `args` are SQL statement parameters and can be referred as `?`.
- Tuple `(String, NamedTuple)`: the `String` is passed to `WHERE` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.
"""
const SET_QUERY_DOC = """
The `qset` part corresponds to the SQL `SET` clause in `UPDATE`. Can be specified in the following ways:
- `NamedTuple`: specified fields correspond to table columns. Values are converted to their SQL types, see `create_table` for details.
- `String`: kept as-is.
- Tuple `(String, NamedTuple)`: the `String` is passed to `SET` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.
"""

""" `collect(tbl::Table, [select])`

Collect all rows from the `tbl` table.

$SELECT_QUERY_DOC
"""
function Base.collect(tbl::Table, select=default_select(tbl))
    map(execute(tbl.db, "select $(select2sql(tbl, select)) from $(tbl.name)")) do r
        process_select_row(tbl.schema, r)
    end
end

""" Select rows from the `tbl` table filtered by the `query`.

$WHERE_QUERY_DOC

$SELECT_QUERY_DOC
"""
function Base.filter(query, tbl::Table, select=default_select(tbl); limit=nothing)
    qstr, params = query_to_sql(tbl, query)
    qres = execute(tbl.db, "select $(select2sql(tbl, select)) from $(tbl.name) where $(qstr) $(limit_to_sql(limit))", params)
    map(qres) do r
        process_select_row(tbl.schema, r)
    end
end

""" `first([query], tbl::Table, [n::Int], [select])`

Select the first row or the first `n` rows from the `tbl` table, optionally filtered by the `query`. Technically, order not specified by SQL and can be arbitrary.

$WHERE_QUERY_DOC

$SELECT_QUERY_DOC
"""
Base.first(query, tbl::Table, select=default_select(tbl)) = filter(query, tbl, select; limit=1) |> only
Base.first(query, tbl::Table, n::Int, select=default_select(tbl)) = filter(query, tbl, select; limit=n)
Base.first(tbl::Table, select=default_select(tbl)) = filter("1", tbl, select; limit=1) |> only
Base.first(tbl::Table, n::Int, select=default_select(tbl)) = filter("1", tbl, select; limit=n)

""" `only(query, tbl::Table, [select])`

Select the only row from the `tbl` table filtered by the `query`. Throw an exception if zero or multiple rows match `query`.

$WHERE_QUERY_DOC

$SELECT_QUERY_DOC
"""
Base.only(query, tbl::Table, select=default_select(tbl)) = filter(query, tbl, select; limit=2) |> only

function sample(query, tbl::Table, n::Int, select=default_select(tbl); replace=true)
    if n > 1 && replace
        throw(ArgumentError("Sampling multiple elements with replacement is not supported"))
    end
    qstr, params = query_to_sql(tbl, query)
    qres = execute(tbl.db, "select $(select2sql(tbl, select)) from $(tbl.name) where $(qstr) order by random() limit $n", params)
    res = map(qres) do r
        process_select_row(tbl.schema, r)
    end
    length(res) < n && error("Cannot draw more samples without replacement")
    return res
end

sample(tbl::Table, n::Int, select=default_select(tbl); replace=true) = sample((;), tbl, n, select; replace)
Base.rand(query, tbl::Table, select=default_select(tbl)) = sample(query, tbl, 1, select) |> only
Base.rand(tbl::Table, select=default_select(tbl)) = rand((;), tbl, select)

## Query doesn't get closed - database may remain locked
# function Iterators.filter(query, tbl::Table, select=default_select(tbl))
#     qstr, params = query_to_sql(tbl, query)
#     qres = execute(tbl.db, "select $(rowid_select_sql(rowid)) * from $(tbl.name) where $(qstr)", params)
#     Iterators.map(qres) do r
#         process_select_row(tbl.schema, r)
#     end
# end

""" `update!(query => qset, tbl::Table)`

Update rows that match `query` with the `qset` specification.

$WHERE_QUERY_DOC

$SET_QUERY_DOC
"""
function update!((qwhere, qset)::Pair, tbl::Table; returning=nothing)
    wstr, wparams = query_to_sql(tbl, qwhere)
    sstr, sparams = setquery_to_sql(tbl, qset)
    ret_str = isnothing(returning) ? "" : "returning $returning"
    execute(tbl.db, "update $(tbl.name) set $(sstr) where $(wstr) $ret_str", merge_nosame(wparams, sparams))
end

""" `updateonly!(query => qset, tbl::Table)`

Update the only row that matches `query` with the `qset` specification. Throw an exception if zero or multiple rows match `query`.

$WHERE_QUERY_DOC

$SET_QUERY_DOC
"""
function updateonly!(queries, tbl::Table)
    qres = update!(queries, tbl; returning=ROWID_NAME) |> rowtable
    isempty(qres) && throw(ArgumentError("No rows were updated. Query: $queries"))
    length(qres) > 1 && throw(ArgumentError("More than one row was updated: $(length(qres)). Query: $queries"))
end

""" `updatesome!(query => qset, tbl::Table)`

Update rows that match `query` with the `qset` specification. Throw an exception if no rows match `query`.

$WHERE_QUERY_DOC

$SET_QUERY_DOC
"""
function updatesome!(queries, tbl::Table)
    qres = update!(queries, tbl; returning=ROWID_NAME) |> rowtable
    isempty(qres) && throw(ArgumentError("No rows were updated. Query: $queries"))
end

""" `delete!(query, tbl::Table)`

Delete rows that match `query` from the `tbl` Table.

$WHERE_QUERY_DOC
"""
function Base.delete!(query, tbl::Table; returning=nothing)
    str, params = query_to_sql(tbl, query)
    ret_str = isnothing(returning) ? "" : "returning $returning"
    execute(tbl.db, "delete from $(tbl.name) where $(str) $ret_str", params)
end

""" `deleteonly!(query, tbl::Table)`

Delete the only row that matches `query` from the `tbl` Table. Throw an exception if zero or multiple rows match `query`.

$WHERE_QUERY_DOC
"""
function deleteonly!(query, tbl::Table)
    qres = delete!(query, tbl; returning=ROWID_NAME) |> rowtable
    isempty(qres) && throw(ArgumentError("No rows were deleted. WHERE query: $query"))
    length(qres) > 1 && throw(ArgumentError("More than one row was deleted: $(length(qres)). WHERE query: $query"))
end

""" `deletesome!(query, tbl::Table)`

Delete rows that match `query` from the `tbl` Table. Throw an exception if no rows match `query`.

$WHERE_QUERY_DOC
"""
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

process_insert_row(row) = map(process_insert_field, row)
process_insert_field(x) = x
process_insert_field(x::DateTime) = Dates.format(x, dateformat"yyyy-mm-dd HH:MM:SS.sss")
process_insert_field(x::Dict) = JSON3.write(x)
process_insert_field(x::Vector) = JSON3.write(x)

process_select_row(schema, row) = process_select_row(schema, NamedTuple(row))
function process_select_row(schema, row::NamedTuple{names}) where {names}
    NamedTuple{names}(map(names) do k
        process_select_field(k == ROWID_NAME ? Rowid : schema[k].type, row[k])
    end)
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
