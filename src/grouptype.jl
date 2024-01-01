struct GroupAny{K,VS}
    key::K
    value::VS
end

struct GroupArray{K,T,N,VS<:AbstractArray{T,N}} <: AbstractArray{T,N}
    key::K
    value::VS
end

const Group{K,VS} = Union{GroupAny{K,VS}, GroupArray{K,<:Any,<:Any,VS}}

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

Base.size(g::GroupArray) = size(value(g))
Base.getindex(g::GroupArray, i...) = getindex(value(g), i...)
Base.getproperty(g::Group, p) = getproperty(value(g), p)
Base.getproperty(g::Group, p::Symbol) = getproperty(value(g), p)  # disambiguate

Base.:(==)(a::Group, b::Group) = key(a) == key(b) && value(a) == value(b)
Base.:(==)(a::Group, b::AbstractArray) = error("Cannot compare Group with $(typeof(b))")
Base.:(==)(a::AbstractArray, b::Group) = error("Cannot compare Group with $(typeof(a))")

group_vg(args...; kwargs...) = group(args...; kwargs..., restype=Vector{Group})
groupview_vg(args...; kwargs...) = groupview(args...; kwargs..., restype=Vector{Group})
groupfind_vg(args...; kwargs...) = groupfind(args...; kwargs..., restype=Vector{Group})
groupmap_vg(args...; kwargs...) = groupmap(args...; kwargs..., restype=Vector{Group})

function _group_core_identity(X, vals, ::Type{Vector{Group}}, len)
    (; dct, starts, rperm) = _group_core_identity(X, vals, AbstractDictionary, len)
    grs = @p dct |> pairs |> map() do (k, gid)
        Group(k, gid)
    end |> collect
    (; dct=grs, starts, rperm)
end
