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
        @test collect(tbl, WithRowid())[3] == (; _rowid_=3, row...)

        @test filter("a = 3", tbl) == [row]
        @test filter(("a = ?", 3), tbl) == [row]
        @test filter(("a = ? and b = ?", 3, "xyz 3"), tbl) == [row]
        @test filter(("a = :xyz", (xyz=3,)), tbl) == [row]
        @test filter((a=3,), tbl) == [row]
        @test filter((d=DateTime(2020, 1, 2, 3, 4, 3),), tbl) == [row]
        @test_broken filter("a <= 3", tbl) == collect(Iterators.filter("a <= 3", tbl))

        @test filter((;), tbl) == collect(tbl)
        @test filter((;), tbl; limit=3) |> length == 3
        @test filter((;), tbl; limit=3)[end] == row
        @test filter((;), tbl; limit=3) == filter("a <= 3", tbl)
        @test filter((a=3, d=DateTime(2020, 1, 2, 3, 4, 4)), tbl) |> isempty
        @test filter((c=Dict(:key => "xxx"),), tbl) |> isempty

        @test first((a=3,), tbl) == row
        @test first("a >= 3", tbl) == row
        @test only((a=3,), tbl) == row
        @test only((b="xyz 3",), tbl) == row
        @test only((a=3, d=DateTime(2020, 1, 2, 3, 4, 3)), tbl) == row
        @test only((c=Dict(:key => "value 3"),), tbl) == row
        @test_throws ArgumentError only((c=Dict(:key => "xxx"),), tbl)
        @test_throws ArgumentError only((;), tbl)
    end

    update("a = 3" => "b = 'def'", tbl)
    @test_throws SQLite.SQLiteException update("a = 5" => ("b = :xyz", (baz="XXX",)), tbl)
    update("a = 5" => ("b = :xyz", (xyz="word",)), tbl)
    update((a=4,) => (b="abc", d=DateTime(1900)), tbl)
    update((a=6,) => (a=60,), tbl)
    updateonly((a=7,) => (a=70,), tbl)
    @test_throws Any updateonly((a=7,) => (a=70,), tbl)
    update((a=-10,) => (a=100,), tbl)
    @test_throws Any updateonly((a=-10,) => (a=100,), tbl)
    @test_throws Any updateonly("a >= 3" => "b = b", tbl)
    updatesome("a >= 3" => "b = b", tbl)
    @test_throws Any updatesome("a < 0" => "b = b", tbl)
    @test only((a=3,), tbl).b == "def"
    @test only((a=5,), tbl).b == "word"
    @test only((a=4,), tbl).b == "abc"
    @test only((a=4,), tbl).d == DateTime(1900)
    @test filter((a=6,), tbl) |> isempty
    @test only((a=60,), tbl).a == 60
    @test only((a=70,), tbl).a == 70

    let r = only((c=Dict("key" => "value 2"),), tbl)
        updateonly(r => (c=Dict(),), tbl)
        @test only((c=Dict(),), tbl).a == 2
    end
    let r = only((c=Dict(),), tbl, WithRowid())
        updateonly((;r._rowid_) => (c=Dict("k" => "v"),), tbl)
        @test only((a=2,), tbl).c == Dict(:k => "v")
    end

    @testset "rowid column" begin
        create_table(db, "tbl_rowid1", @NamedTuple{x::Int})
        create_table(db, "tbl_rowid2", @NamedTuple{x::Union{Int, Missing}})
        create_table(db, "tbl_rowid3", @NamedTuple{x::Rowid})
        
        @test_throws SQLite.SQLiteException push!(table(db, "tbl_rowid1"), (;))
        push!(table(db, "tbl_rowid2"), (;))
        @test only((;), table(db, "tbl_rowid2")).x === missing
        push!(table(db, "tbl_rowid3"), (;))
        @test only((;), table(db, "tbl_rowid3")).x == 1
    end
end


import CompatHelperLocal as CHL
CHL.@check()
