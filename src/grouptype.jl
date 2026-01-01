struct GroupAny{K,VS}
    key::K
    value::VS
end

struct GroupArray{K,T,N,VS<:AbstractArray{T,N}} <: AbstractArray{T,N}
    key::K
    value::VS
end

const Group{K,VS} = Union{GroupAny{K,VS}, GroupArray{K,<:Any,<:Any,VS}}

_Grouptype(::Type{K}, ::Type{VS}) where {K, VS} = GroupAny{K, VS}
_Grouptype(::Type{K}, ::Type{VS}) where {K, VS<:AbstractArray} = GroupArray{K, VS}

Group(key, value) = GroupAny(key, value)
Group(key, value::AbstractArray) = GroupArray(key, value)
AccessorsExtra.constructorof(::Type{<:Group}) = Group

key(g::Group) = getfield(g, :key)
value(g::Group) = getfield(g, :value)
Base.values(g::Group) = value(g)

Accessors.set(g::Group, ::typeof(key), k) = Group(k, value(g))
Accessors.set(g::Group, ::typeof(value), v) = Group(key(g), v)
Accessors.set(g::Group, ::typeof(values), v::AbstractArray) = Group(key(g), v)
Accessors.modify(f, obj::Group, ::GroupValue) = modify(f, obj, value)

Base.similar(A::GroupArray) = similar(values(A))
Base.similar(A::GroupArray, ::Type{T}) where {T} = similar(values(A), T)
Base.similar(A::GroupArray, dims::Tuple) = similar(values(A), dims)
Base.similar(A::GroupArray, ::Type{T}, dims::Tuple{Union{Integer, Base.OneTo}, Vararg{Union{Integer, Base.OneTo}}}) where {T} = similar(values(A), T, dims)
Base.similar(A::GroupArray, ::Type{T}, dims::Tuple{Vararg{Int, N}}) where {T, N} = similar(values(A), T, dims)  # disambiguation

Base.length(g::Group) = length(value(g))
Base.size(g::Group) = size(value(g))
Base.keys(g::Group) = keys(value(g))
Base.first(g::Group) = first(value(g))
Base.lastindex(g::Group) = lastindex(value(g))
Base.getindex(g::Group, i...) = getindex(value(g), i...)
Base.getproperty(g::Group, p) = getproperty(value(g), p)
Base.getproperty(g::Group, p::Symbol) = getproperty(value(g), p)  # disambiguate
Base.map(f, g::Group) = map(f, value(g))
Base.mapreduce(f, op, itr::Group) = mapreduce(f, op, value(itr))

Base.:(==)(a::Group, b::Group) = key(a) == key(b) && value(a) == value(b)
Base.:(==)(a::Group, b::AbstractArray) = error("Cannot compare Group with $(typeof(b))")
Base.:(==)(a::AbstractArray, b::Group) = error("Cannot compare Group with $(typeof(a))")

group_vg(args...; kwargs...) = group(args...; kwargs..., restype=AbstractVector{Group})
groupview_vg(args...; kwargs...) = groupview(args...; kwargs..., restype=AbstractVector{Group})
groupfind_vg(args...; kwargs...) = groupfind(args...; kwargs..., restype=AbstractVector{Group})
groupmap_vg(args...; kwargs...) = groupmap(args...; kwargs..., restype=AbstractVector{Group})

function _group_core_identity(X, vals, ::Type{AbstractVector{Group}}, len)
    (; dct, starts, rperm) = _group_core_identity(X, vals, AbstractDictionary, len)
    result = similar(vals, _Grouptype(keytype(dct), valtype(dct)), length(dct))
    for (i, (k, gid)) in zip(eachindex(result), pairs(dct))
        @inbounds result[i] = Group(k, gid)
    end
    (; dct=result, starts, rperm)
end
