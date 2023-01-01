### A Pluto.jl notebook ###
# v0.19.3

using Markdown
using InteractiveUtils

# ╔═╡ 8d5fac0e-c95a-11ec-0cea-d720897ec2f1
begin
	using Revise
	import Pkg
	eval(:(Pkg.develop(path="..")))
	Pkg.resolve()
	using SQLStore
end

# ╔═╡ ae2d5cd9-7bd3-4a10-ae13-841b68622a3e
using DataPipes, SplitApplyCombine

# ╔═╡ 8f673d64-3c02-4750-bfc9-84fe66434a60
md"""
# Tables as collections
"""

# ╔═╡ 8cd78512-c26f-40a7-a745-ef829a56219e
md"""
Open an SQLite database (in-memory for this example):
"""

# ╔═╡ 06a750cc-ca11-41ac-87fc-3b00a338f04e
db = SQLite.DB()

# ╔═╡ 0d047cbb-d5ba-4877-b3a3-e46995d2ea7f
md"""
Create a table based on a schema:
"""

# ╔═╡ d70ca976-58d7-4b1d-a047-2fc8a4538a11
create_table(db, "mytbl", @NamedTuple{a::Int, b::Union{Missing, String}, c::SQLStore.JSON, d::SQLStore.Serialized}; constraints="PRIMARY KEY (a)")

# ╔═╡ 70d35e9c-cdbf-483f-a16c-854b0140e066
md"""
That's how its SQLite definition looks like:
"""

# ╔═╡ 7fee024f-9eb9-4082-93dc-c12df940e09f
SQLStore.sql_table_def(db, "mytbl") |> Text

# ╔═╡ bb8e4ae5-a121-4442-95fc-b7251d064016
md"""
Access the created table afterwards:
"""

# ╔═╡ 177110bd-19a0-43a9-9227-0e0da71e3463
tbl = table(db, "mytbl")

# ╔═╡ b38d9887-38b8-45d0-b559-898468c16a96
schema(tbl)

# ╔═╡ d9bf1a38-2140-4d72-8e63-27d0b3c35ae6
md"""
These tables implement functions from the array interface:
"""

# ╔═╡ 38263968-bcfa-4d9f-bb23-da0b1b37b386
append!(tbl, [
	(a=1, b="abc", c=Dict("a" => 1), d=(x=123, y=[1, 2, "5"])),
	(a=2, b=missing, c=Dict("b" => 2), d=(x=123, y=[1, 2, "5"])),
])

# ╔═╡ b3277a64-6da5-44d7-8caa-dc71a72e259c
collect(tbl)

# ╔═╡ 34ac6096-af3a-4da8-a9b2-c955db201f30
length(tbl)

# ╔═╡ 22338b27-0bfc-4827-b238-dfb373cee369
md"""
Some functions that typically take a function predicate (`filter`, `count`, ...), require a `NamedTuple` as the predicate instead:
"""

# ╔═╡ c63a5a6f-6b4b-437a-870f-e5f99e788a64
filter((;b="abc"), tbl)

# ╔═╡ 8ef971e0-5e46-44d3-8283-1d8357e2a1c6
md"""
The predicate is interpreted as per-column equality, so that it could be pushed as a `WHERE` clause to `SQLite`. This gives the same result as the above:
"""

# ╔═╡ a505505d-10cf-4e04-83bf-96305bd6627c
filter(x -> isequal(x.b, "abc"), collect(tbl))

# ╔═╡ 408e0f9f-85f0-4ce9-a0c0-c96e7d96cb46
md"""
The `WHERE` clause can be passed as a string directly:
"""

# ╔═╡ e6c27a07-3ce0-4721-868a-2a46d6d42092
count("a = 1", tbl)

# ╔═╡ f3355263-e50e-4a93-abc5-fd8bcd93bd23
only("a > 1", tbl)

# ╔═╡ 02e65523-ec29-4eec-8468-9fa8792dab5e
md"""
See also `update!` and `delete!` function families.
"""

# ╔═╡ b1c251e0-c142-4dc2-83e3-a8a958c701db
md"""
# Tables as dictionaries
"""

# ╔═╡ d7fdab20-84bb-475b-b2f1-8bc1b47b1eb9
md"""
SQLite tables can also be used as `Dict`-like containers.

Wrap a table into an `SQLDict`, creating it if not present:
"""

# ╔═╡ f9e265dd-a3dc-4131-b342-9b1a00683e18
dct = SQLDict{String, SQLStore.Serialized}(table(db, "dcttbl"))

# ╔═╡ a25daf01-46f5-4996-88f4-cc88230d90a0
md"""
Regular `Dict` operations:
"""

# ╔═╡ 10b90e15-4b54-473e-831b-f1bd7960bed5
dct["abc"] = 1234

# ╔═╡ 7789c7a1-fb5e-4ef2-96f1-e07c9342101c
dct["ABC"] = [1, 2, (x=1,)]

# ╔═╡ 58ba07c7-3be2-4329-9c21-af4cbbcdccdc
pop!(dct, "a", :default)

# ╔═╡ 6628e792-38b1-4536-a77c-2b2a59db9954
dct

# ╔═╡ 8ad6eaf7-01b7-4d7f-a4c6-53bd7578c675
Dict(dct)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
DataPipes = "02685ad9-2d12-40c3-9f73-c6aeda6a7ff5"
Pkg = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
Revise = "295af30f-e4ad-537b-8983-00126c2a3abe"
SQLStore = "fadf0b4e-86bc-4bbb-a4ee-5c756d629598"
SplitApplyCombine = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66"

[compat]
DataPipes = "~0.2.11"
Revise = "~3.3.3"
SQLStore = "~0.1.12"
SplitApplyCombine = "~1.2.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.0-beta3"
manifest_format = "2.0"
project_hash = "0ebab33b456c4fe5a0209dd14c8de435c6d48b72"

[[deps.Accessors]]
deps = ["Compat", "CompositionsBase", "ConstructionBase", "Future", "LinearAlgebra", "MacroTools", "Requires", "Test"]
git-tree-sha1 = "0264a938934447408c7f0be8985afec2a2237af4"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.11"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BinaryProvider]]
deps = ["Libdl", "Logging", "SHA"]
git-tree-sha1 = "ecdec412a9abc8db54c0efc5548c64dfce072058"
uuid = "b99e7846-7c00-51b0-8f62-c81ae34c0232"
version = "0.5.10"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "9950387274246d08af38f6eef8cb5480862a435f"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.14.0"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "bf98fa45a0a4cee295de98d4c1462be26345b9a1"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.2"

[[deps.CodeTracking]]
deps = ["InteractiveUtils", "UUIDs"]
git-tree-sha1 = "6d4fa04343a7fc9f9cb9cff9558929f3d2752717"
uuid = "da1fd8a2-8d9e-5ec2-8556-3022fb5608a2"
version = "1.0.9"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "b153278a25dd42c65abbf4e62344f9d22e59191b"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.43.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "0.5.2+0"

[[deps.CompositionsBase]]
git-tree-sha1 = "455419f7e328a1a2493cabc6428d79e951349769"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.1"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f74e9d5388b8620b4cee35d4c5a618dd4dc547f4"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.3.0"

[[deps.DBInterface]]
git-tree-sha1 = "9b0dc525a052b9269ccc5f7f04d5b3639c65bca5"
uuid = "a10d1c49-ce27-4219-8d33-6db1a4562965"
version = "2.5.0"

[[deps.DataAPI]]
git-tree-sha1 = "fb5f5316dd3fd4c5e7c30a24d50643b73e37cd40"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.10.0"

[[deps.DataPipes]]
deps = ["Accessors", "SplitApplyCombine"]
git-tree-sha1 = "121461472b58969da1987fcd4e6f18111b3fa925"
uuid = "02685ad9-2d12-40c3-9f73-c6aeda6a7ff5"
version = "0.2.11"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3daef5523dd2e769dad2365274f760ff5f282c7d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.11"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.Dictionaries]]
deps = ["Indexing", "Random"]
git-tree-sha1 = "0340cee29e3456a7de968736ceeb705d591875a2"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.3.20"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "61feba885fac3a407465726d0c330b3055df897f"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.1.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "91b5dcf362c5add98049e6c29ee756910b03051d"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.3"

[[deps.InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "StructTypes", "UUIDs"]
git-tree-sha1 = "8c1f668b24d999fb47baf80436194fdccec65ad2"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.9.4"

[[deps.JuliaInterpreter]]
deps = ["CodeTracking", "InteractiveUtils", "Random", "UUIDs"]
git-tree-sha1 = "52617c41d2761cc05ed81fe779804d3b7f14fff7"
uuid = "aa1ae85d-cabe-5617-a682-6adf51b2e16a"
version = "0.9.13"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.81.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "44a7b7bb7dd1afe12bac119df6a7e540fa2c96bc"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.13"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoweredCodeUtils]]
deps = ["JuliaInterpreter"]
git-tree-sha1 = "dedbebe234e06e1ddad435f5c6f4b85cd8ce55f7"
uuid = "6f1432cf-f94c-5a45-995e-cdbf5db27b0b"
version = "2.2.2"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.20+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "1285416549ccfcdf0c50d4997a94331e88d68413"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.3.1"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Revise]]
deps = ["CodeTracking", "Distributed", "FileWatching", "JuliaInterpreter", "LibGit2", "LoweredCodeUtils", "OrderedCollections", "Pkg", "REPL", "Requires", "UUIDs", "Unicode"]
git-tree-sha1 = "4d4239e93531ac3e7ca7e339f15978d0b5149d03"
uuid = "295af30f-e4ad-537b-8983-00126c2a3abe"
version = "3.3.3"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SQLStore]]
deps = ["DBInterface", "DataAPI", "DataPipes", "Dates", "InvertedIndices", "JSON3", "SQLite", "StatsBase", "Tables"]
path = "../../home/aplavin/.julia/dev/SQLStore"
uuid = "fadf0b4e-86bc-4bbb-a4ee-5c756d629598"
version = "0.1.12"

[[deps.SQLite]]
deps = ["BinaryProvider", "DBInterface", "Dates", "Libdl", "Random", "SQLite_jll", "Serialization", "Tables", "Test", "WeakRefStrings"]
git-tree-sha1 = "c19088908cde014f8807e6dc57b90cb5b5c90565"
uuid = "0aa819cd-b072-5ff4-a722-6bc24af294d9"
version = "1.4.1"

[[deps.SQLite_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "f79c1c58951ea4f5bb63bb96b99bf7f440a3f774"
uuid = "76ed43ae-9a5d-5a62-8c75-30186b810ce8"
version = "3.38.0+0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SplitApplyCombine]]
deps = ["Dictionaries", "Indexing"]
git-tree-sha1 = "35efd62f6f8d9142052d9c7a84e35cd1f9d2db29"
uuid = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66"
version = "1.2.1"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "c82aaa13b44ea00134f8c9c89819477bd3986ecd"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.3.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "8977b17906b0a1cc74ab2e3a05faa16cf08a8291"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.16"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "d24a825a95a6d98c385001212dc9020d609f2d4f"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.8.1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "5ce79ce186cc678bbb5c5681ca3379d1ddae11a1"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.7.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.1.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.41.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "16.2.1+1"
"""

# ╔═╡ Cell order:
# ╠═ae2d5cd9-7bd3-4a10-ae13-841b68622a3e
# ╠═8d5fac0e-c95a-11ec-0cea-d720897ec2f1
# ╟─8f673d64-3c02-4750-bfc9-84fe66434a60
# ╟─8cd78512-c26f-40a7-a745-ef829a56219e
# ╠═06a750cc-ca11-41ac-87fc-3b00a338f04e
# ╟─0d047cbb-d5ba-4877-b3a3-e46995d2ea7f
# ╠═d70ca976-58d7-4b1d-a047-2fc8a4538a11
# ╟─70d35e9c-cdbf-483f-a16c-854b0140e066
# ╠═7fee024f-9eb9-4082-93dc-c12df940e09f
# ╟─bb8e4ae5-a121-4442-95fc-b7251d064016
# ╠═177110bd-19a0-43a9-9227-0e0da71e3463
# ╠═b38d9887-38b8-45d0-b559-898468c16a96
# ╟─d9bf1a38-2140-4d72-8e63-27d0b3c35ae6
# ╠═38263968-bcfa-4d9f-bb23-da0b1b37b386
# ╠═b3277a64-6da5-44d7-8caa-dc71a72e259c
# ╠═34ac6096-af3a-4da8-a9b2-c955db201f30
# ╟─22338b27-0bfc-4827-b238-dfb373cee369
# ╠═c63a5a6f-6b4b-437a-870f-e5f99e788a64
# ╟─8ef971e0-5e46-44d3-8283-1d8357e2a1c6
# ╠═a505505d-10cf-4e04-83bf-96305bd6627c
# ╟─408e0f9f-85f0-4ce9-a0c0-c96e7d96cb46
# ╠═e6c27a07-3ce0-4721-868a-2a46d6d42092
# ╠═f3355263-e50e-4a93-abc5-fd8bcd93bd23
# ╟─02e65523-ec29-4eec-8468-9fa8792dab5e
# ╟─b1c251e0-c142-4dc2-83e3-a8a958c701db
# ╟─d7fdab20-84bb-475b-b2f1-8bc1b47b1eb9
# ╠═f9e265dd-a3dc-4131-b342-9b1a00683e18
# ╟─a25daf01-46f5-4996-88f4-cc88230d90a0
# ╠═10b90e15-4b54-473e-831b-f1bd7960bed5
# ╠═7789c7a1-fb5e-4ef2-96f1-e07c9342101c
# ╠═58ba07c7-3be2-4329-9c21-af4cbbcdccdc
# ╠═6628e792-38b1-4536-a77c-2b2a59db9954
# ╠═8ad6eaf7-01b7-4d7f-a4c6-53bd7578c675
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
