# SQLStore.jl

Use SQLite tables as Array- or Dict-like collections.

`SQLStore.jl` is not an ORM and doesn't try to be. It effectively maps SQL tables to the simplest Julia collections, following Array and Dict interfaces as possible.

`SQLStore.jl` supports both native SQLite datatypes and serialization to JSON or Julia Serialization formats. It automatically creates table schemas based on Julia types, adding constraints when necessary. As an example, for a field of Julia type `Int`, the SQLite column definition is `colname int not null check (typeof(colname) = 'integer')`. This ensures that only values of proper types can end up in the table, despite the lack of strict typing in SQLite itself.

For array-like collections, `SQLStore.jl` uses `push!` to insert elements into the collection. Selection and filtering uses functions like `collect`, `filter`, `only` and others. Main data modification functions: `update!`, `updateonly!`, `updatesome!`, and similarly with `delete!`. Values of supported Julia types are automatically converted to/from corresponding SQLite types.

See the [Pluto notebook]() for more examples, and docstrings for more details on specific functions.

