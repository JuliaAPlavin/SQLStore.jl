using SQLStore
import SQLite
using Dates: DateTime, now
using DBInterface: execute
using Test

@testset begin
    db = SQLite.DB()
    create_table(db, "tbl_nt", @NamedTuple{a::Int, b, c::String, d::Union{String, Missing}, x::DateTime, y::Float64})
    create_table(db, "tbl_pk", @NamedTuple{a::Int, b::String, c::Dict, d::DateTime}; constraint="PRIMARY KEY (a)")

    tbl = table(db, "tbl_pk")
    @show tbl
    @test length(tbl) == 0
    for i in 1:10
        push!(tbl, (a=i, b="xyz $i", c=Dict("key" => "value $i"), d=DateTime(2020, 1, 2, 3, 4, i)))
    end
    @test_throws SQLite.SQLiteException push!(tbl, (a=1, b="", c=Dict(), d=now()))
    @test length(tbl) == 10
    @test length(collect(tbl)) == 10

    @test count("a = 3", tbl) == 1
    @test count((;a=3), tbl) == 1
    @test count("a >= 3", tbl) == 8
    @test any("a >= 3", tbl)

    let row = (a=3, b="xyz 3", c=Dict(:key => "value 3"), d=DateTime(2020, 1, 2, 3, 4, 3))
        @test collect(tbl)[3] == row

        @test filter("a = 3", tbl) == [row]
        @test filter(("a = ?", 3), tbl) == [row]
        @test filter(("a = ? and b = ?", 3, "xyz 3"), tbl) == [row]
        @test filter(("a = :xyz", (xyz=3,)), tbl) == [row]
        @test filter((a=3,), tbl) == [row]
        @test filter((d=DateTime(2020, 1, 2, 3, 4, 3),), tbl) == [row]
        @test filter("a <= 3", tbl) == collect(Iterators.filter("a <= 3", tbl))

        @test filter((;), tbl) == collect(tbl)
        @test filter((;), tbl; limit=3) |> length == 3
        @test filter((;), tbl; limit=3)[end] == row
        @test filter((;), tbl; limit=3) == filter("a <= 3", tbl)
        @test filter((a=3, d=DateTime(2020, 1, 2, 3, 4, 4)), tbl) |> isempty
        @test filter((c=Dict(:key => "xxx"),), tbl) |> isempty

        @test only((a=3,), tbl) == row
        @test only((b="xyz 3",), tbl) == row
        @test only((a=3, d=DateTime(2020, 1, 2, 3, 4, 3)), tbl) == row
        @test only((c=Dict(:key => "value 3"),), tbl) == row
        @test_throws ArgumentError only((c=Dict(:key => "xxx"),), tbl)
        @test_throws ArgumentError only((;), tbl)
    end

    
end


import CompatHelperLocal as CHL
CHL.@check()
