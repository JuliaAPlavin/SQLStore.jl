limit_to_sql(lim::Nothing) = ""
limit_to_sql(lim::Int) = "limit $lim"


const ROWID_NAME = :_rowid_

""" `Rowid()` has two uses in `SQLStore`.
- In `create_table()`: specify that a field is an `SQLite` `rowid`, that is `integer primary key`.
- In select column definitions: specify that the table `rowid` should explicitly be included in the results. The returned rowid field is named `$ROWID_NAME`.
"""
struct Rowid end

# for backwards compatibility - WithRowid was used in SQLStore before
abstract type RowidSpec end
struct WithRowid <: RowidSpec end

const SELECT_QUERY_DOC = """
Each row corresponds to a `NamedTuple`. Fields are converted according to the table `schema`, see `create_table` for details.

The optional `select` argument specifies fields to return, in one of the following ways.
- `All()`, the default: select all columns.
- A `Symbol`: select a single column by name.
- `Rowid()`: select the SQLite rowid column, named $ROWID_NAME in the results.
- `Cols(...)`: multiple columns, each defined as above.
- `Not(...)`: all columns excluding those listed in `Not`.
"""

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


const WHERE_QUERY_DOC = """
The filtering `query` corresponds to the SQL `WHERE` clause. It can be specified in one of the following forms:
- `NamedTuple`: specified fields are matched against corresponding table columns, combined with `AND`. Values are converted to corresponding SQL types, see `create_table` for details.
- `String`: kept as-is.
- Tuple `(String, args...)`: the `String` is passed to `WHERE` as-is, `args` are SQL statement parameters and can be referred as `?`.
- Tuple `(String, NamedTuple)`: the `String` is passed to `WHERE` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.
"""

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

const SET_QUERY_DOC = """
The `qset` part corresponds to the SQL `SET` clause in `UPDATE`. Can be specified in the following ways:
- `NamedTuple`: specified fields correspond to table columns. Values are converted to their SQL types, see `create_table` for details.
- `String`: kept as-is.
- Tuple `(String, NamedTuple)`: the `String` is passed to `SET` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.
"""

setquery_to_sql(tbl, q::AbstractString) = q, (;)
setquery_to_sql(tbl, q::NamedTuple) = @p begin
    @aside prefix = :_SET_
    map(keys(q), values(q)) do k, v
        "$k = :$prefix$k"
    end
    return join(↑, ", "), add_prefix_to_fieldnames(process_insert_row(q), Val(prefix))
end
setquery_to_sql(tbl, q::Tuple{AbstractString, NamedTuple}) = first(q), last(q)
