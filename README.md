
<a id='SQLStore.jl'></a>

<a id='SQLStore.jl-1'></a>

# SQLStore.jl


<a id='Reference'></a>

<a id='Reference-1'></a>

# Reference

<a id='Base.Iterators.only' href='#Base.Iterators.only'>#</a>
**`Base.Iterators.only`** &mdash; *Function*.



`only(query, tbl::Table, [select])`

Select the only row from the `tbl` table filtered by the `query`. Throw an exception if zero or multiple rows match `query`.

The filtering `query` corresponds to the SQL `WHERE` clause. It can be specified in one of the following forms:

  * `NamedTuple`: specified fields are matched against corresponding table columns, combined with `AND`. Values are converted to corresponding SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, args...)`: the `String` is passed to `WHERE` as-is, `args` are SQL statement parameters and can be referred as `?`.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `WHERE` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.

Each row corresponds to a `NamedTuple`. Fields are converted according to the table `schema`, see `create_table` for details.

The optional `select` argument specifies fields to return, in one of the following ways.

  * `All()`, the default: select all columns.
  * A `Symbol`: select a single column by name.
  * `Rowid()`: select the SQLite rowid column, named *rowid* in the results.
  * `Cols(...)`: multiple columns, each defined as above.
  * `Not(...)`: all columns excluding those listed in `Not`.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L258-L266' class='documenter-source'>source</a><br>

<a id='Base.collect' href='#Base.collect'>#</a>
**`Base.collect`** &mdash; *Function*.



`collect(tbl::Table, [select])``

Collect all rows from the `tbl` table.

Each row corresponds to a `NamedTuple`. Fields are converted according to the table `schema`, see `create_table` for details.

The optional `select` argument specifies fields to return, in one of the following ways.

  * `All()`, the default: select all columns.
  * A `Symbol`: select a single column by name.
  * `Rowid()`: select the SQLite rowid column, named *rowid* in the results.
  * `Cols(...)`: multiple columns, each defined as above.
  * `Not(...)`: all columns excluding those listed in `Not`.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L219-L225' class='documenter-source'>source</a><br>

<a id='Base.delete!-Tuple{Any, SQLStore.Table}' href='#Base.delete!-Tuple{Any, SQLStore.Table}'>#</a>
**`Base.delete!`** &mdash; *Method*.



`delete!(query, tbl::Table)`

Delete rows that match `query` from the `tbl` Table.

The filtering `query` corresponds to the SQL `WHERE` clause. It can be specified in one of the following forms:

  * `NamedTuple`: specified fields are matched against corresponding table columns, combined with `AND`. Values are converted to corresponding SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, args...)`: the `String` is passed to `WHERE` as-is, `args` are SQL statement parameters and can be referred as `?`.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `WHERE` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L336-L342' class='documenter-source'>source</a><br>

<a id='Base.filter' href='#Base.filter'>#</a>
**`Base.filter`** &mdash; *Function*.



Select rows from the `tbl` table filtered by the `query`.

The filtering `query` corresponds to the SQL `WHERE` clause. It can be specified in one of the following forms:

  * `NamedTuple`: specified fields are matched against corresponding table columns, combined with `AND`. Values are converted to corresponding SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, args...)`: the `String` is passed to `WHERE` as-is, `args` are SQL statement parameters and can be referred as `?`.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `WHERE` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.

Each row corresponds to a `NamedTuple`. Fields are converted according to the table `schema`, see `create_table` for details.

The optional `select` argument specifies fields to return, in one of the following ways.

  * `All()`, the default: select all columns.
  * A `Symbol`: select a single column by name.
  * `Rowid()`: select the SQLite rowid column, named *rowid* in the results.
  * `Cols(...)`: multiple columns, each defined as above.
  * `Not(...)`: all columns excluding those listed in `Not`.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L231-L237' class='documenter-source'>source</a><br>

<a id='Base.first' href='#Base.first'>#</a>
**`Base.first`** &mdash; *Function*.



`first([query], tbl::Table, [n::Int], [select])`

Select the first row or the first `n` rows from the `tbl` table, optionally filtered by the `query`. Technically, order not specified by SQL and can be arbitrary.

The filtering `query` corresponds to the SQL `WHERE` clause. It can be specified in one of the following forms:

  * `NamedTuple`: specified fields are matched against corresponding table columns, combined with `AND`. Values are converted to corresponding SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, args...)`: the `String` is passed to `WHERE` as-is, `args` are SQL statement parameters and can be referred as `?`.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `WHERE` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.

Each row corresponds to a `NamedTuple`. Fields are converted according to the table `schema`, see `create_table` for details.

The optional `select` argument specifies fields to return, in one of the following ways.

  * `All()`, the default: select all columns.
  * A `Symbol`: select a single column by name.
  * `Rowid()`: select the SQLite rowid column, named *rowid* in the results.
  * `Cols(...)`: multiple columns, each defined as above.
  * `Not(...)`: all columns excluding those listed in `Not`.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L245-L253' class='documenter-source'>source</a><br>

<a id='Base.push!-Tuple{SQLStore.Table, NamedTuple}' href='#Base.push!-Tuple{SQLStore.Table, NamedTuple}'>#</a>
**`Base.push!`** &mdash; *Method*.



`push!(tbl::Table, row::NamedTuple)`

Insert the `row` to `tbl`. Field values are converted to SQL types.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L120-L124' class='documenter-source'>source</a><br>

<a id='SQLStore.create_table-Tuple{Any, AbstractString, Type{<:NamedTuple}}' href='#SQLStore.create_table-Tuple{Any, AbstractString, Type{<:NamedTuple}}'>#</a>
**`SQLStore.create_table`** &mdash; *Method*.



`create_table(db, name, T::Type{NamedTuple}; [constraints])`

Create a table with `name` in the database `db` with column specifications derived from the type `T`. Table constraints can be specified by the `constraints` argument.

Supported types:

  * `Int`, `Float64`, `String` are directly stored as corresponding SQL types.
  * `Bool`s stored as `0` and `1` `INTEGER`s.
  * `DateTime`s are stored as `TEXT` with the `'%Y-%m-%d %H:%M:%f'` format.
  * `Dict`s and `Vector`s get translated to their `JSON` representations.
  * Any type can be combined with `Missing` as in `Union{Int, Missing}`. This allows `NULL`s in the corresponding column.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L31-L38' class='documenter-source'>source</a><br>

<a id='SQLStore.deleteonly!-Tuple{Any, SQLStore.Table}' href='#SQLStore.deleteonly!-Tuple{Any, SQLStore.Table}'>#</a>
**`SQLStore.deleteonly!`** &mdash; *Method*.



`deleteonly!(query, tbl::Table)`

Delete the only row that matches `query` from the `tbl` Table. Throw an exception if zero or multiple rows match `query`.

The filtering `query` corresponds to the SQL `WHERE` clause. It can be specified in one of the following forms:

  * `NamedTuple`: specified fields are matched against corresponding table columns, combined with `AND`. Values are converted to corresponding SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, args...)`: the `String` is passed to `WHERE` as-is, `args` are SQL statement parameters and can be referred as `?`.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `WHERE` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L348-L354' class='documenter-source'>source</a><br>

<a id='SQLStore.deletesome!-Tuple{Any, SQLStore.Table}' href='#SQLStore.deletesome!-Tuple{Any, SQLStore.Table}'>#</a>
**`SQLStore.deletesome!`** &mdash; *Method*.



`deletesome!(query, tbl::Table)`

Delete rows that match `query` from the `tbl` Table. Throw an exception if no rows match `query`.

The filtering `query` corresponds to the SQL `WHERE` clause. It can be specified in one of the following forms:

  * `NamedTuple`: specified fields are matched against corresponding table columns, combined with `AND`. Values are converted to corresponding SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, args...)`: the `String` is passed to `WHERE` as-is, `args` are SQL statement parameters and can be referred as `?`.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `WHERE` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L360-L366' class='documenter-source'>source</a><br>

<a id='SQLStore.table-Tuple{Any, AbstractString}' href='#SQLStore.table-Tuple{Any, AbstractString}'>#</a>
**`SQLStore.table`** &mdash; *Method*.



Obtain the `SQLStore.Table` object corresponding to the table `name` in database `db`.

The returned object supports:

  * `SELECT`ing rows with `collect`, `filter`, `first`, `only`. Random row selection: `sample`, `rand`.
  * `UPDATE`ing rows with `update!`, `updateonly!`, `updatesome!`.
  * `DELETE`ing rows with `delete!`, `deleteonly!`, `deletesome!`.
  * `INSERT`ing rows with `push!`, `append!`.
  * Retrieving metadata with `schema`, `columnnames`, `ncol`.
  * Other: `nrow`, `length`, `count`, `any`.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L63-L73' class='documenter-source'>source</a><br>

<a id='SQLStore.update!-Tuple{Pair, SQLStore.Table}' href='#SQLStore.update!-Tuple{Pair, SQLStore.Table}'>#</a>
**`SQLStore.update!`** &mdash; *Method*.



`update!(query => qset, tbl::Table)`

Update rows that match `query` with the `qset` specification.

The filtering `query` corresponds to the SQL `WHERE` clause. It can be specified in one of the following forms:

  * `NamedTuple`: specified fields are matched against corresponding table columns, combined with `AND`. Values are converted to corresponding SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, args...)`: the `String` is passed to `WHERE` as-is, `args` are SQL statement parameters and can be referred as `?`.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `WHERE` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.

The `qset` part corresponds to the SQL `SET` clause in `UPDATE`. Can be specified in the following ways:

  * `NamedTuple`: specified fields correspond to table columns. Values are converted to their SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `SET` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L294-L302' class='documenter-source'>source</a><br>

<a id='SQLStore.updateonly!-Tuple{Any, SQLStore.Table}' href='#SQLStore.updateonly!-Tuple{Any, SQLStore.Table}'>#</a>
**`SQLStore.updateonly!`** &mdash; *Method*.



`updateonly!(query => qset, tbl::Table)`

Update the only row that matches `query` with the `qset` specification. Throw an exception if zero or multiple rows match `query`.

The filtering `query` corresponds to the SQL `WHERE` clause. It can be specified in one of the following forms:

  * `NamedTuple`: specified fields are matched against corresponding table columns, combined with `AND`. Values are converted to corresponding SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, args...)`: the `String` is passed to `WHERE` as-is, `args` are SQL statement parameters and can be referred as `?`.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `WHERE` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.

The `qset` part corresponds to the SQL `SET` clause in `UPDATE`. Can be specified in the following ways:

  * `NamedTuple`: specified fields correspond to table columns. Values are converted to their SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `SET` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L309-L317' class='documenter-source'>source</a><br>

<a id='SQLStore.updatesome!-Tuple{Any, SQLStore.Table}' href='#SQLStore.updatesome!-Tuple{Any, SQLStore.Table}'>#</a>
**`SQLStore.updatesome!`** &mdash; *Method*.



`updatesome!(query => qset, tbl::Table)`

Update rows that match `query` with the `qset` specification. Throw an exception if no rows match `query`.

The filtering `query` corresponds to the SQL `WHERE` clause. It can be specified in one of the following forms:

  * `NamedTuple`: specified fields are matched against corresponding table columns, combined with `AND`. Values are converted to corresponding SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, args...)`: the `String` is passed to `WHERE` as-is, `args` are SQL statement parameters and can be referred as `?`.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `WHERE` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.

The `qset` part corresponds to the SQL `SET` clause in `UPDATE`. Can be specified in the following ways:

  * `NamedTuple`: specified fields correspond to table columns. Values are converted to their SQL types, see `create_table` for details.
  * `String`: kept as-is.
  * Tuple `(String, NamedTuple)`: the `String` is passed to `SET` as-is, the `NamedTuple` contains SQL statement parameters that can be referred by name, `:param_name`.


<a target='_blank' href='https://github.com/aplavin/SQLStore.jl/blob/cddc6ead7c9bff55fa3fd0d08770712e9b553115/src/SQLStore.jl#L323-L331' class='documenter-source'>source</a><br>

