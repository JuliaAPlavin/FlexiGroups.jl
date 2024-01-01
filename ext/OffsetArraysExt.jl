module OffsetArraysExt

using OffsetArrays
import FlexiGroups: _group_core_identity, _similar_1based, _valtype

function _group_core_identity(X, vals, ::Type{OffsetVector}, len)
    @assert _valtype(X) == Int
    dct = Base.IdentityUnitRange(minimum(X):maximum(X))
    ngroups = length(dct)

    starts = zeros(Int, first(dct):(last(dct)+1))
    starts[begin] = 1
    @inbounds for gid in X
        starts[gid+1] += 1
    end
    cumsum!(starts, starts)
    # now starts[gid] is the (#elements in groups begin:gid-1) + 1
    # or the index of the first element of group gid in (future) rperm

    rperm = _similar_1based(vals, length(X))
    for (v, gid) in zip(vals, X)
        rperm[starts[gid]] = v
        starts[gid] += 1
    end
    # now starts[gid] is the index just after the last element of group gid in rperm
    for gid in X
        starts[gid] -= 1
    end

    # dct: key -> group_id
    # rperm[starts[group_id]:starts[group_id+1]-1] = group_values
    return (; dct, starts, rperm)
end


end
