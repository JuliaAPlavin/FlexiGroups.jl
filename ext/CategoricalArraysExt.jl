module CategoricalArraysExt
using CategoricalArrays
using FlexiGroups
import FlexiGroups: _group_core_identity, _default_concrete_dict, _similar_1based

function _group_core_identity(X::AbstractArray{<:CategoricalValue}, vals, ::Type{DT}, length::Integer) where {DT <: FlexiGroups.DICTS}
    if isempty(X)
        return @invoke _group_core_identity(X::AbstractArray, vals, DT, length)
    end
    ngroups = 0
    groups = Vector{Int}(undef, length)
    dct = _default_concrete_dict(DT)(
        # only works for Dictionary, not Dict
        levels(first(X)),
        1:Base.length(levels(first(X)))
    )
    ngroups = Base.length(dct)
    @inbounds for (i, x) in enumerate(X)
        groups[i] = dct[unwrap(x)]
    end

    starts = zeros(Int, ngroups)
    @inbounds for gid in groups
        starts[gid] += 1
    end
    cumsum!(starts, starts)
    push!(starts, length)

    rperm = _similar_1based(vals, length)
    @inbounds for (v, gid) in zip(vals, groups)
        rperm[starts[gid]] = v
        starts[gid] -= 1
    end

    # dct: key -> group_id
    # rperm[starts[group_id + 1]:-1:1 + starts[group_id]] = group_values

    return (; dct, starts, rperm)
end

end
