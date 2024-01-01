struct Group{K,VS}
    key::K
    value::VS
end

@accessor key(g::Group) = g.key
@accessor value(g::Group) = g.value
@accessor Base.values(g::Group) = g.value
Accessors.modify(f, obj::Group, ::GroupValue) = modify(f, obj, value)

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

