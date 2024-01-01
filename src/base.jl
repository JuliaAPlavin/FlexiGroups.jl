"""    group([keyf=identity], X; [restype=Dictionary])

Group elements of `X` by `keyf(x)`, returning a mapping `keyf(x)` values to lists of `x` values in each group.

The result is an (ordered) `Dictionary` by default, but can be specified to be a base `Dict` as well.

Alternatively to dictionaries, specifying `restype=KeyedArray` (from `AxisKeys.jl`) results in a `KeyedArray`. Its `axiskeys` are the group keys.

# Examples

```julia
xs = 3 .* [1, 2, 3, 4, 5]
g = group(isodd, xs)
g == dictionary([true => [3, 9, 15], false => [6, 12]])


g = group(x -> (a=isodd(x),), xs; restype=KeyedArray)
g == KeyedArray([[6, 12], [3, 9, 15]]; a=[false, true])
```
"""
function group end

"""    groupview([keyf=identity], X; [restype=Dictionary])

Like the `group` function, but each group is a `view` of `X`: doesn't copy the input elements.
"""
function groupview end

"""    groupmap([keyf=identity], mapf, X; [restype=Dictionary])

Like `map(mapf, group(keyf, X))`, but more efficient. Supports a limited set of `mapf` functions: `length`, `first`/`last`, `only`, `rand`.
"""
function groupmap end

group(X; kwargs...) = group(identity, X; kwargs...)
groupfind(X; kwargs...) = groupfind(identity, X; kwargs...)
groupview(X; kwargs...) = groupview(identity, X; kwargs...)
groupmap(mapf, X; kwargs...) = groupmap(identity, mapf, X; kwargs...)

group(f, X; restype=AbstractDictionary, kwargs...) = _group(f, X, restype; kwargs...)
groupfind(f, X; restype=AbstractDictionary, kwargs...) = _groupfind(f, X, restype; kwargs...)
groupview(f, X; restype=AbstractDictionary, kwargs...) = _groupview(f, X, restype; kwargs...)
groupmap(f, mapf, X; restype=AbstractDictionary, kwargs...) = _groupmap(f, mapf, X, restype; kwargs...)


const DICTS = Union{AbstractDict, AbstractDictionary}

function _groupfind(f, X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(values(dct)[∗]) do gid
        @view rperm[starts[gid]:starts[gid + 1]-1]
    end
end

function _groupview(f, X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(values(dct)[∗]) do gid
        ix = @view rperm[starts[gid]:starts[gid + 1]-1]
        @view X[ix]
    end
end

function _group(f, X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, values(X), RT)
    @modify(values(dct)[∗]) do gid
        @view rperm[starts[gid]:starts[gid + 1]-1]
    end
end

function _groupmap(f, ::typeof(length), X, ::Type{RT}) where {RT <: DICTS}
    vals = similar(X, Nothing)
    fill!(vals, nothing)
    (; dct, starts, rperm) = _group_core(f, X, vals, RT)
    @modify(values(dct)[∗]) do gid
        starts[gid + 1] - starts[gid]
    end
end

function _groupmap(f, ::typeof(first), X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(values(dct)[∗]) do gid
        ix = rperm[starts[gid]]
        X[ix]
    end
end

function _groupmap(f, ::typeof(last), X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(values(dct)[∗]) do gid
        ix = rperm[starts[gid + 1] - 1]
        X[ix]
    end
end

function _groupmap(f, ::typeof(only), X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(values(dct)[∗]) do gid
        starts[gid + 1] == starts[gid] + 1 || throw(ArgumentError("groupmap(only, X) requires that each group has exactly one element"))
        ix = rperm[starts[gid]]
        X[ix]
    end
end

function _groupmap(f, ::typeof(rand), X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(values(dct)[∗]) do gid
        ix = rperm[rand(starts[gid]:starts[gid + 1]-1)]
        X[ix]
    end
end


_group_core(f, X::AbstractArray, vals, dicttype) = _group_core(f, X, vals, dicttype, length(X))
_group_core(f, X, vals, dicttype) = _group_core(f, X, vals, dicttype, Base.IteratorSize(X) isa Base.SizeUnknown ? missing : length(X))
_group_core(f, X, vals, dicttype, length) = _group_core_identity(mapview(f, X), vals, dicttype, length)

# Bool group keys: fastpath for performance
function _group_core_identity(X::AbstractArray{Bool}, vals, ::Type{AbstractDictionary}, length::Integer)
    ngroups = 0
    true_first = isempty(X) ? false : first(X)
    dct = isempty(X) ? ArrayDictionary(ArrayIndices(Bool[]), Int[]) : ArrayDictionary(ArrayIndices([true_first, !true_first]), [1, 2])

    rperm = _similar_1based(vals, length)
    i0 = 1
    i1 = length
    @inbounds for (v, gid) in zip(vals, X)
        if gid == true_first
            rperm[i0] = v
            i0 += 1
        else
            rperm[i1] = v
            i1 -= 1
        end
    end
    reverse!(@view(rperm[i0:end]))

    if i0 == length + 1 && length > 0
        delete!(dct, !true_first)
    end
    starts = [1, i0, length+1]

    return (; dct, starts, rperm)
end

function _group_core_identity(X, vals, ::Type{DT}, len) where {DT}
    ngroups = 0
    dct = _default_concrete_dict(DT){_valtype(X), Int}()
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

function _group_core_identity(X::AbstractArray{MultiGroup{GT}}, vals, ::Type{DT}, len) where {DT,GT}
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

if VERSION < v"1.10-"
    _similar_1based(vals::AbstractArray, len::Integer) = similar(vals, len)
    _similar_1based(vals, len::Integer) = Vector{_eltype(vals)}(undef, len)
else
    # applicable() is compiletime in 1.10+
    _similar_1based(vals, len::Integer) = applicable(similar, vals, len) ? similar(vals, len) : Vector{_eltype(vals)}(undef, len)
end
