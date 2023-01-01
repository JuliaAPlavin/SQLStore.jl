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
include("table.jl")

end
