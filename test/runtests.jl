using SQLStore
using Dates: DateTime, now
using DBInterface: execute
using Test


db = SQLite.DB()
create_table(db, "tbl_pk", @NamedTuple{a::Int, b::String, c::SQLStore.JSON, d::DateTime}; constraints="PRIMARY KEY (a)")

@testset "create table" begin
    tbl = create_table(db, "tbl_1", @NamedTuple{a::Int, b::String, c::Dict, d::DateTime}; constraints="PRIMARY KEY (a)")
    @test tbl.name == "tbl_1"
    @test schema(tbl).names == (:a, :b, :c, :d)
    @test table(db, "tbl_1") == tbl
    @test_throws ErrorException create_table(db, "tbl_1", @NamedTuple{a::Int, b::String, c::SQLStore.JSON, d::DateTime}; constraints="PRIMARY KEY (a)")
    @test create_table(db, "tbl_1", @NamedTuple{a::Int, b::String, c::SQLStore.JSON, d::DateTime}; constraints="PRIMARY KEY (a)", keep_compatible=true) == tbl
    @test_throws ErrorException create_table(db, "tbl_1", @NamedTuple{a::Int, b::String, c::SQLStore.JSON, d::DateTime}; keep_compatible=true)
    @test_throws ErrorException create_table(db, "tbl_1", @NamedTuple{a::Int, b::String}; constraints="PRIMARY KEY (a)", keep_compatible=true)
    @test_throws ErrorException create_table(db, "tbl_1", @NamedTuple{a::Union{Int, Missing}, b::String, c::SQLStore.JSON, d::DateTime}; constraints="PRIMARY KEY (a)", keep_compatible=true)
end

@testset "populate table" begin
    tbl = table(db, "tbl_pk")
    @test length(tbl) == 0
    @test isempty(tbl)
    for i in 1:5
        push!(tbl, (a=i, b="xyz $i", c=Dict("key" => "value $i"), d=DateTime(2020, 1, 2, 3, 4, i)))
    end
    @test_throws SQLite.SQLiteException push!(tbl, (a=1, b="", c=Dict(), d=now()))
    @test !isempty(tbl)
    @test length(tbl) == 5
    append!(tbl, [
        (a=i, b="xyz $i", c=Dict("key" => "value $i"), d=DateTime(2020, 1, 2, 3, 4, i))
        for i in 6:10
    ])
    @test length(tbl) == 10
    @test length(collect(tbl)) == 10
end

@testset "summaries" begin
    tbl = table(db, "tbl_pk")
    @test schema(tbl).names == (:a, :b, :c, :d)
    @test schema(tbl).types == (Int, String, SQLStore.JSON, DateTime)
    @test columnnames(tbl) == (:a, :b, :c, :d)
    @test nrow(tbl) == 10
    @test ncol(tbl) == 4
    @test count("a = 3", tbl) == 1
    @test count((;a=3), tbl) == 1
    @test count("a >= 3", tbl) == 8
    @test any("a >= 3", tbl)
end

@testset "select" begin
    tbl = table(db, "tbl_pk")
    row = (a=3, b="xyz 3", c=Dict(:key => "value 3"), d=DateTime(2020, 1, 2, 3, 4, 3))
    @test collect(tbl)[3] == row
    @test collect(tbl, WithRowid())[3] == (; _rowid_=3, row...)
    @test collect(tbl, All())[3] == row
    @test collect(tbl, Cols(:a, :b))[3] == (; a=3, b="xyz 3")
    @test collect(tbl, Cols(:a, Rowid(), :b))[3] == (; a=3, _rowid_=3, b="xyz 3")
    @test collect(tbl, Not(:c))[3] == (a=3, b="xyz 3", d=DateTime(2020, 1, 2, 3, 4, 3))
    @test collect(tbl, Not((:c, :d)))[3] == (a=3, b="xyz 3")

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

    @test first(tbl) == collect(tbl)[1]
    @test first((a=3,), tbl) == row
    @test first("a >= 3", tbl) == row
    @test first((a=3,), tbl, 0) == []
    @test first((a=3,), tbl, 5) == [row]
    @test first(tbl, 5) == collect(tbl)[1:5]

    @test only((a=3,), tbl) == row
    @test only((b="xyz 3",), tbl) == row
    @test only((a=3, d=DateTime(2020, 1, 2, 3, 4, 3)), tbl) == row
    @test only((c=Dict(:key => "value 3"),), tbl) == row
    @test_throws ArgumentError only((c=Dict(:key => "xxx"),), tbl)
    @test_throws ArgumentError only((;), tbl)
end

@testset "random" begin
    tbl = table(db, "tbl_pk")
    let rows = collect(tbl)
        @test rand(tbl) ∈ rows

        @test_throws ArgumentError sample(tbl, 3)
        @test length(sample(tbl, 3; replace=false)) == 3
        @test issubset(sample(tbl, 3; replace=false), rows)
        @test length(unique(sample(tbl, 3; replace=false))) == 3

        @test sort(sample(tbl, 10; replace=false)) == sort(rows)
        @test_throws ErrorException sample(tbl, 100; replace=false)
    end
    let rows = filter("a >= 3", tbl)
        @test rand("a >= 3", tbl) ∈ rows

        @test_throws ArgumentError sample("a >= 3", tbl, 3)
        @test length(sample("a >= 3", tbl, 3; replace=false)) == 3
        @test issubset(sample("a >= 3", tbl, 3; replace=false), rows)
        @test length(unique(sample("a >= 3", tbl, 3; replace=false))) == 3

        @test sort(sample("a >= 3", tbl, 8; replace=false)) == sort(rows)
        @test_throws ErrorException sample("a >= 3", tbl, 100; replace=false)
    end
end

@testset "update" begin
    tbl = table(db, "tbl_pk")
    update!("a = 3" => "b = 'def'", tbl)
    @test_throws SQLite.SQLiteException update!("a = 5" => ("b = :xyz", (baz="XXX",)), tbl)
    update!("a = 5" => ("b = :xyz", (xyz="word",)), tbl)
    update!((a=4,) => (b="abc", d=DateTime(1900)), tbl)
    update!((a=6,) => (a=60,), tbl)
    updateonly!((a=7,) => (a=70,), tbl)
    @test_throws ArgumentError updateonly!((a=7,) => (a=70,), tbl)
    update!((a=-10,) => (a=100,), tbl)
    @test_throws ArgumentError updateonly!((a=-10,) => (a=100,), tbl)
    @test_throws ArgumentError updateonly!("a >= 3" => "b = b", tbl)
    updatesome!("a >= 3" => "b = b", tbl)
    @test_throws ArgumentError updatesome!("a < 0" => "b = b", tbl)
    @test only((a=3,), tbl).b == "def"
    @test only((a=5,), tbl).b == "word"
    @test only((a=4,), tbl).b == "abc"
    @test only((a=4,), tbl).d == DateTime(1900)
    @test filter((a=6,), tbl) |> isempty
    @test only((a=60,), tbl).a == 60
    @test only((a=70,), tbl).a == 70

    let r = only((c=Dict("key" => "value 2"),), tbl)
        updateonly!(r => (c=Dict(),), tbl)
        @test only((c=Dict(),), tbl).a == 2
    end
    let r = only((c=Dict(),), tbl, WithRowid())
        updateonly!((;r._rowid_) => (c=Dict("k" => "v"),), tbl)
        @test only((a=2,), tbl).c == Dict(:k => "v")
    end
end

@testset "delete" begin
    tbl = table(db, "tbl_pk")
    @test length(tbl) == 10
    delete!("a >= 10", tbl)
    @test length(tbl) == 7
    deleteonly!((a=1,), tbl)
    @test length(tbl) == 6
    @test_throws ArgumentError deleteonly!((a=1,), tbl)
    @test_throws ArgumentError deletesome!((a=1,), tbl)
    @test length(tbl) == 6
    deletesome!((a=2,), tbl)
    @test length(tbl) == 5
end

@testset "rowid column" begin
    create_table(db, "tbl_rowid1", @NamedTuple{x::Int})
    create_table(db, "tbl_rowid2", @NamedTuple{x::Union{Int, Missing}})
    create_table(db, "tbl_rowid3", @NamedTuple{x::Rowid})
    create_table(db, "tbl_rowid4", @NamedTuple{x::Union{Int, Missing}}; constraints="primary key (x)")
    
    @test_throws SQLite.SQLiteException push!(table(db, "tbl_rowid1"), (;))
    push!(table(db, "tbl_rowid2"), (;))
    push!(table(db, "tbl_rowid3"), (;))
    push!(table(db, "tbl_rowid4"), (;))
    @test only((;), table(db, "tbl_rowid2")).x === missing
    @test only((;), table(db, "tbl_rowid3")).x == 1
    @test only((;), table(db, "tbl_rowid4")).x === missing
end

# ensure that no open sqlite statements are kept - otherwise dropping table would error
execute(db, "drop table tbl_pk")

@testset "more complex types" begin
    create_table(db, "tbl_nt", @NamedTuple{a::Union{Int, Missing}, b::SQLStore.JSON, c::SQLStore.Serialized})
    tbl = table(db, "tbl_nt")
    # all are valid...
    push!(tbl, (a=1, b=Dict(:a => 5), c=[1, 2, 3]))
    push!(tbl, (a=missing, b=[1, 2, 3], c=[1, 2, 3]))
    push!(tbl, (a=3, b=Dict(:a => 5), c=Dict(:a => 5)))
    push!(tbl, (a=4, b=[1, 2, 3], c=Dict(:a => 5)))
    @test length(tbl) == 4
    @test isequal([r.a for r in collect(tbl)], [1, missing, 3, 4])
    @test only((;a=1), tbl) == (a=1, b=Dict(:a => 5), c=[1, 2, 3])
    @test isequal(only((;a=missing), tbl), (a=missing, b=[1, 2, 3], c=[1, 2, 3]))
    @test isequal(only("a is null", tbl), (a=missing, b=[1, 2, 3], c=[1, 2, 3]))
    @test only((;a=4), tbl) == (a=4, b=[1, 2, 3], c=Dict(:a => 5))
end

if Threads.nthreads() == 1
    @warn "Julia is started with a single thread, cannot test multithreading"
end
@testset "multithreaded" begin
    create_table(db, "tbl_thread", @NamedTuple{a::Union{Int, Missing}, b::SQLStore.Serialized, c::SQLStore.JSON})
    tbl = table(db, "tbl_thread")
    N = 1000
    @sync for i in 1:N
        Threads.@spawn push!(tbl, (a=i, b=Dict("key" => "value $i"), c=rand(i)))
    end
    @test length(tbl) == N
    @sync for i in 1:N
        @async push!(tbl, (a=N + i, b=Dict("key" => "value $i"), c=rand(i)))
    end
    @test length(tbl) == 2*N
    Threads.@threads for i in 1:N
        push!(tbl, (a=2*N + i, b=Dict("key" => "value $i"), c=rand(i)))
    end
    @test length(tbl) == 3*N
    @test asyncmap(i -> only((a=i,), tbl), 1:(3*N)) == sort(collect(tbl), by=r -> r.a)
    foreach(collect(tbl)) do r
        @test r.b["key"] == "value $(mod1(r.a, N))"
        @test length(r.c) == mod1(r.a, N)
    end
end

@testset "dict basic" begin
    dct = SQLDict{String, Int}(table(db, "dcttbl"))
    @test keytype(dct) == String
    @test valtype(dct) == Int
    @test length(dct) == 0
    @test isempty(dct)
    @test_throws KeyError dct["abc"]
    @test_throws Exception dct[123]

    dct["abc"] = 1
    @test length(dct) == 1
    @test !isempty(dct)
    @test dct["abc"] == 1
    @test_throws KeyError dct["def"]
    @test_throws Exception dct[123]

    @test delete!(dct, "abc") === dct
    @test isempty(dct)
    @test delete!(dct, "abc") === dct  # doesn't throw

    dct["abc"] = 10
    dct["d"] = 20
    @test length(dct) == 2
    @test collect(dct) == ["abc" => 10, "d" => 20]
    @test (dct["abc"] += 1) == 11
    @test dct["abc"] == 11
    @test haskey(dct, "d")
    @test "d" ∈ keys(dct)
    @test !haskey(dct, "ABC")
    @test "ABC" ∉ keys(dct)
    @test get(dct, "d", nothing) === 20
    @test get(dct, "D", nothing) === nothing
    @test pop!(dct, "d") == 20
    @test pop!(dct, "d", 0) == 0
    @test !haskey(dct, "d")

    @test first(dct) == ("abc" => 11)

    @test get!(dct, "abc", nothing) == 11
    @test get!(dct, "ABC", 123) == 123
    @test dct["ABC"] == 123
    @test get!(dct, "ABC", nothing) == 123
    @test get!(() -> 456, dct, "def") == 456
    @test get!(() -> error(""), dct, "def") == 456
    @test dct["def"] == 456
    @test collect(dct) == ["abc" => 11, "ABC" => 123, "def" => 456]

    empty!(dct)
    @test isempty(dct)
end

@testset "dict complex types" begin
    dct = SQLDict{SQLStore.Serialized, SQLStore.JSON}(table(db, "dct2"))
    @test keytype(dct) == Any
    @test valtype(dct) == Any
    dct["abc"] = 123
    dct[(a="abc", b=123)] = [1, 2, 3]
    @test dct["abc"] == 123
    @test dct[(a="abc", b=123)] == [1, 2, 3]
    dct[(a="abc", b=123)] = Dict(:a => [4, 5, 6])
    @test collect(dct) == ["abc" => 123, (a="abc", b=123) => Dict(:a => [4, 5, 6])]
end


import CompatHelperLocal as CHL
CHL.@check()
import Aqua
Aqua.test_all(SQLStore; ambiguities=false, unbound_args=false)

# using Documenter, DocumenterMarkdown
# makedocs(format=Markdown(), modules=[SQLStore], root="../docs")
# mv("../docs/build/README.md", "../README.md", force=true)
# rm("../docs/build", recursive=true)
