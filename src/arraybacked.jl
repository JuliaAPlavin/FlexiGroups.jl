function _group_core_identity(X, vals, ::Type{Vector}, len)
    @assert _valtype(X) == Int
    @assert minimum(X) ≥ 1
    ngroups = maximum(X)
    dct = Base.OneTo(ngroups)

    starts = zeros(Int, ngroups)
    @inbounds for gid in X
        starts[gid] += 1
    end
    # now starts[gid] is the number of elements in group gid
    pushfirst!(starts, 1)
    cumsum!(starts, starts)
    # now starts[gid] is the (#elements in groups 1:gid-1) + 1
    # or the index of the first element of group gid in (future) rperm

    rperm = _similar_1based(vals, length(X))
    @inbounds for (v, gid) in zip(vals, X)
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
