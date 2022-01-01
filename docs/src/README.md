# SQLStore.jl

Use SQLite databases as persistent collections.

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
