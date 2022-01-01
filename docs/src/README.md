# SQLStore.jl

Use SQLite tables as persistent collections.

`SQLStore.jl` is not an ORM and doesn't try to be. It effectively maps SQL tables to the simplest Julia tables, `Vector{NamesTuple}`s.

`SQLStore.jl` specifically focuses on native SQLite datatypes and excludes any Julia-specific serializations. It creates table schemas based on Julia types, adding constraints when necessary. As an example, for a field of Julia type `Int`, the SQLite column definition is `colname int not null check (typeof(colname) = 'integer')`. This ensures that only values of proper types can end up in the table, despite the lack of strict typing in SQLite itself.

`SQLStore.jl` uses `push!` to insert elements into the collection. Selection and filtering uses functions like `collect`, `filter`, `only` and others. Main data modification functions: `update!`, `updateonly!`, `updatesome!`, and similarly with `delete!`. Values of supported Julia types are automatically converted to/from corresponding SQLite types. See reference for the full list and function documentation.

# Usage

Basic usage example:

```jldoctest
julia> using SQLStore

julia> using Dates

julia> db = SQLite.DB();  # in-memory database for the sake of example

julia> create_table(
           db, "table_name",
           @NamedTuple{a::Int, b::String, c::Dict, d::DateTime};
           constraints="PRIMARY KEY (a)"
       );

julia> tbl = table(db, "table_name");

julia> schema(tbl)
Tables.Schema:
 :a  Int64
 :b  String
 :c  Dict
 :d  DateTime

julia> for i in 1:10
           push!(tbl, (a=i, b="xyz $i", c=Dict("key" => "value $i"), d=DateTime(2020, 1, 2, 3, 4, 5)))
       end

julia> length(tbl)
10

julia> only((;a=3), tbl)
(a = 3, b = "xyz 3", c = Dict{Symbol, Any}(:key => "value 3"), d = DateTime("2020-01-02T03:04:05"))

julia> count("a >= 3", tbl)
8

julia> filter((d=DateTime(2020, 1, 2, 3, 4, 5),), tbl) |> length
10
```

See function references for more details.

# Reference

```@docs
create_table
table
```

```@autodocs
Modules = [SQLStore]
Order = [:function]
Filter = t -> t ∉ (create_table, table)
```
