
# Bool group keys: fastpath for performance
function _group_core_identity(X::AbstractArray{Bool}, vals, ::Type{AbstractDictionary}, length::Integer)
    ngroups = 0
    true_first = isempty(X) ? false : first(X)
    dct = isempty(X) ? ArrayDictionary(ArrayIndices(Bool[]), Int[]) : ArrayDictionary(ArrayIndices([true_first, !true_first]), [1, 2])

    rperm = _similar_1based(vals, length)
    i0 = 1
    i1 = length
    @inbounds for (v, gid) in zip(vals, X)
        atstart = gid == true_first
        rperm[atstart ? i0 : i1] = v
        atstart ? (i0 += 1) : (i1 -= 1)
    end
    reverse!(@view(rperm[i0:end]))

    if i0 == length + 1 && length > 0
        delete!(dct, !true_first)
    end
    starts = [1, i0, length+1]

    return (; dct, starts, rperm)
end

function _group_core_identity(X, vals, ::Type{DT}, len) where {DT<:DICTS}
    ngroups = 0
    dct = _default_concrete_dict(DT){eltype(X), Int}()
    groups = _groupid_container(len)
    @inbounds for (i, x) in enumerate(X)
        gid = get!(dct, x, ngroups + 1)
        _push_or_set!(groups, i, gid, len)
        if gid == ngroups + 1
            ngroups += 1
        end
    end

    starts = zeros(Int, ngroups)
    @inbounds for gid in groups
        starts[gid] += 1
    end
    # now starts[gid] is the number of elements in group gid
    pushfirst!(starts, 1)
    cumsum!(starts, starts)
    # now starts[gid] is the (#elements in groups 1:gid-1) + 1
    # or the index of the first element of group gid in (future) rperm

    rperm = _similar_1based(vals, length(groups))
    @inbounds for (v, gid) in zip(vals, groups)
        rperm[starts[gid]] = v
        starts[gid] += 1
    end
    # now starts[gid] is the index just after the last element of group gid in rperm
    for gid in groups
        starts[gid] -= 1
    end

    # dct: key -> group_id
    # rperm[starts[group_id]:starts[group_id+1]-1] = group_values
    return (; dct, starts, rperm)
end

struct MultiGroup{G}
    groups::G
end
Base.hash(mg::MultiGroup, h::UInt) = error("Deliberately unsupported, should be unreachable")

function _group_core_identity(X::AbstractArray{MultiGroup{GT}}, vals, ::Type{DT}, len) where {DT<:DICTS,GT}
    ngroups = Ref(0)
    dct = _default_concrete_dict(DT){eltype(GT), Int}()
    groups = Vector{_similar_container_type(GT, Int)}(undef, len)
    @inbounds for (i, x) in enumerate(X)
        groups[i] = map(x.groups) do gkey
            gid = get!(dct, gkey, ngroups[] + 1)
            if gid == ngroups[] + 1
                ngroups[] += 1
            end
            return gid
        end
    end

    starts = zeros(Int, ngroups[])
    @inbounds for gids in groups
        for gid in gids
            starts[gid] += 1
        end
    end
    cumsum!(starts, starts)
    push!(starts, sum(length, groups))

    rperm = _similar_1based(vals, sum(length, groups))
    @inbounds for (v, gids) in zip(vals, groups)
        for gid in gids
            rperm[starts[gid]] = v
            starts[gid] -= 1
        end
    end

    return (; dct, starts, rperm)
end

_groupid_container(len::Missing) = Int[]
_push_or_set!(groups, i, gid, len::Missing) = push!(groups, gid)

_groupid_container(len::Integer) = Vector{Int}(undef, len)
_push_or_set!(groups, i, gid, len::Integer) = groups[i] = gid

_similar_container_type(::Type{<:AbstractArray}, ::Type{T}) where {T} = Vector{T}
_similar_container_type(::Type{<:NTuple{N,Any}}, ::Type{T}) where {N,T} = NTuple{N,T}


_default_concrete_dict(::Type{AbstractDict}) = Dict
_default_concrete_dict(::Type{AbstractDictionary}) = Dictionary
_default_concrete_dict(::Type{T}) where {T} = T
