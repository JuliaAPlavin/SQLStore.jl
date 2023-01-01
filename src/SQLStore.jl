module SQLStore

import DBInterface
using Dates
import JSON3
import Tables
using Tables: rowtable, schema, columnnames
using DataPipes
using InvertedIndices: Not
import DataAPI: All, Cols, ncol, nrow
import StatsBase: sample
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


include("utils.jl")
include("sql.jl")
include("conversion.jl")


""" `create_table(db, name, T::Type{NamedTuple}; [constraints], [keep_compatible=false])`

Create a table with `name` in the database `db` with column specifications derived from the type `T`.
Table constraints can be specified by the `constraints` argument.
Throws if a table with the same `name` already exists, unless `keep_compatible` is passed. `keep_compatible=true` keeps the existing table if it has a compatible schema.

$SUPPORTED_TYPES_DOC
"""
function create_table(db, table_name::AbstractString, T::Type{<:NamedTuple}; constraints=nothing, keep_compatible=false)
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

    existing_sql_def = try
        sql_table_def(db, table_name)
    catch ex
        ex isa ArgumentError || rethrow()
        nothing
    end
    if isnothing(existing_sql_def)
        # table doesn't exist: create it
        execute(db, stmt)
    else
        is_compatible = stmt == existing_sql_def
        if !keep_compatible
            is_compatible ?
                error("Table $table_name already exists in $db. Matches the requested schema, pass 'keep_compatible=true' to keep.") :
                error("Table $table_name already exists in $db and doesn't matche the requested schema.")
        elseif !is_compatible
            error("Table $table_name already exists in $db and doesn't matche the requested schema.")
        end
        @assert keep_compatible && is_compatible
    end
    return table(db, table_name)
end

Base.@kwdef struct Table
    db
    name::String
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
    schema = parse_sql_to_schema(sql_table_def(db, name))
    Table(; db, name, schema)
end

sql_table_def(db, name::AbstractString) = @p execute(db, "select * from sqlite_schema where name = :name", (;name)) |> rowtable |> only |> __.sql

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

function Base.isempty(tbl::Table)
    r = execute(tbl.db, "select exists (select 1 from $(tbl.name))") |> rowtable |> only |> only
    @assert r ∈ (0, 1)
    return r == 0
end

function Base.count(query, tbl::Table)
    qstr, params = query2sql(tbl, query)
    execute(tbl.db, "select count(*) from $(tbl.name) where $(qstr)", params) |> rowtable |> only |> only
end

function Base.any(query, tbl::Table)
    qstr, params = query2sql(tbl, query)
    !isempty(execute(tbl.db, "select $ROWID_NAME from $(tbl.name) where $(qstr) limit 1", params) |> rowtable)
end


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
    qstr, params = query2sql(tbl, query)
    qres = execute(tbl.db, "select $(select2sql(tbl, select)) from $(tbl.name) where $(qstr) $(limit2sql(limit))", params)
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
    qstr, params = query2sql(tbl, query)
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
#     qstr, params = query2sql(tbl, query)
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
    wstr, wparams = query2sql(tbl, qwhere)
    sstr, sparams = setquery2sql(tbl, qset)
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
    str, params = query2sql(tbl, query)
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

end
