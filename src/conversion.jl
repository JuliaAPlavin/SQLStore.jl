const SUPPORTED_TYPES_DOC = """
Supported types:
- `Int`, `Float64`, `String` are directly stored as corresponding SQL types.
- `Bool`s stored as `0` and `1` `INTEGER`s.
- `DateTime`s are stored as `TEXT` with the `'%Y-%m-%d %H:%M:%f'` format.
- `Dict`s and `Vector`s get translated to their `JSON` representations.
- Any type can be combined with `Missing` as in `Union{Int, Missing}`. This allows `NULL`s in the corresponding column.
"""

struct Serialized end
struct JSON end


actual_julia_type(T::Type) = T
actual_julia_type(::Type{<:JSON}) = Any
actual_julia_type(::Type{<:Serialized}) = Any


colspec(name, ::Type{Rowid}) = "$name integer primary key"
function colspec(name, T::Type)
    ct = coltype(T)
    cc = colcheck(name, T)
    spec = isempty(cc) ? "$name $ct" : "$name $ct check ($cc)"
    strip(spec)
end

# specify integer type as "int", not "integer": we don't want our columns to become rowid
# this is done for more reliable updating
coltype(::Type{Bool}) = "int not null"
coltype(::Type{Int}) = "int not null"
coltype(::Type{Float64}) = "real not null"
coltype(::Type{String}) = "text not null"
coltype(::Type{DateTime}) = "text not null"
coltype(::Type{Dict}) = (Base.depwarn("Pass SQLStore.JSON as type instead", :coltype); "text not null")
coltype(::Type{Vector}) = (Base.depwarn("Pass SQLStore.JSON as type instead", :coltype); "text not null")
coltype(::Type{JSON}) = "text not null"
coltype(::Type{Serialized}) = "blob not null"
coltype(::Type{Any}) = ""
coltype(::Type{Union{T, Missing}}) where {T} = replace(coltype(T), " not null" => "")

colcheck(name, ::Type{Bool}) = "$name in (0, 1)"
colcheck(name, ::Type{Int}) = "typeof($name) = 'integer'"
colcheck(name, ::Type{Float64}) = "typeof($name) = 'real'"
colcheck(name, ::Type{String}) = "typeof($name) = 'text'"
colcheck(name, ::Type{DateTime}) = "typeof($name) = 'text' and $name == strftime('%Y-%m-%d %H:%M:%f', $name)"
colcheck(name, ::Type{Dict}) = (Base.depwarn("Pass SQLStore.JSON as type instead", :colcheck); "json_valid($name)")
colcheck(name, ::Type{Vector}) = (Base.depwarn("Pass SQLStore.JSON as type instead", :colcheck); "json_valid($name)")
colcheck(name, ::Type{JSON}) = "json_valid($name)"
colcheck(name, ::Type{Serialized}) = ""
colcheck(name, ::Type{Any}) = ""
colcheck(name, ::Type{Union{T, Missing}}) where {T} = "($(colcheck(name, T))) or $name is null"


@generated function process_insert_row(schema, row::NamedTuple{names}) where {names}
    values = map(names) do k
        T = k == ROWID_NAME ? :(Rowid) : :(schema.$k.type)
        :(process_insert_field($T, row.$k))
    end
    :( NamedTuple{$names}(($(values...),)) )
end
process_insert_field(T::Type, x) = x::T
process_insert_field(::Type{Rowid}, x) = x::Int
process_insert_field(::Type{DateTime}, x::DateTime) = Dates.format(x, dateformat"yyyy-mm-dd HH:MM:SS.sss")
process_insert_field(::Type{JSON}, x) = JSON3.write(x)
function process_insert_field(::Type{Serialized}, x)
    buffer = IOBuffer()
    Serialization.serialize(buffer, x)
    return take!(buffer)
end

process_select_row(schema, row::SQLite.Row) = process_select_row(schema, row, Val(Tuple(Tables.columnnames(row))))
@generated function process_select_row(schema, row, ::Val{names}) where {names}
    values = map(enumerate(names)) do (i, k)
        T = k == ROWID_NAME ? :(Rowid) : :(schema.$k.type)
        :(process_select_field($T, Tables.getcolumn(row, $i)))
    end
    :( NamedTuple{$names}(($(values...),)) )
end
process_select_field(T::Type, x) = x::T
process_select_field(::Type{Bool}, x) = Bool(x)
process_select_field(::Type{Rowid}, x) = x::Int
process_select_field(::Type{DateTime}, x) = DateTime(x, dateformat"yyyy-mm-dd HH:MM:SS.sss")
process_select_field(::Type{JSON}, x) = _json_materialize(JSON3.read(x))
process_select_field(::Type{Serialized}, x) = Serialization.deserialize(IOBuffer(x))

_json_materialize(x::String) = x
_json_materialize(x) = copy(x)
