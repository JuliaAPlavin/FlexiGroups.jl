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
    mapvalues(dct) do gid
        @view rperm[starts[gid + 1]:-1:1 + starts[gid]]
    end
end

function _groupview(f, X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    mapvalues(dct) do gid
        ix = @view rperm[starts[gid + 1]:-1:1 + starts[gid]]
        @view X[ix]
    end
end

function _group(f, X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, values(X), RT)
    mapvalues(dct) do gid
        @view rperm[starts[gid + 1]:-1:1 + starts[gid]]
    end
end

function _groupmap(f, ::typeof(length), X, ::Type{RT}) where {RT <: DICTS}
    vals = similar(X, Nothing)
    fill!(vals, nothing)
    (; dct, starts, rperm) = _group_core(f, X, vals, RT)
    mapvalues(dct) do gid
        starts[gid + 1] - starts[gid]
    end
end

function _groupmap(f, ::typeof(first), X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    mapvalues(dct) do gid
        ix = rperm[starts[gid + 1]]
        X[ix]
    end
end

function _groupmap(f, ::typeof(last), X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    mapvalues(dct) do gid
        ix = rperm[1 + starts[gid]]
        X[ix]
    end
end

function _groupmap(f, ::typeof(only), X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    mapvalues(dct) do gid
        starts[gid + 1] == starts[gid] + 1 || throw(ArgumentError("groupmap(only, X) requires that each group has exactly one element"))
        ix = rperm[starts[gid + 1]]
        X[ix]
    end
end

function _groupmap(f, ::typeof(rand), X, ::Type{RT}) where {RT <: DICTS}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    mapvalues(dct) do gid
        ix = rperm[rand(starts[gid + 1]:-1:1 + starts[gid])]
        X[ix]
    end
end


_group_core(f, X::AbstractArray, vals, dicttype) = _group_core(f, X, vals, dicttype, length(X))
_group_core(f, X, vals, dicttype) = _group_core(f, X, vals, dicttype, Base.IteratorSize(X) isa Base.SizeUnknown ? missing : length(X))
_group_core(f, X, vals, dicttype, length) = _group_core_identity(mapview(f, X), vals, dicttype, length)

function _group_core_identity(X::AbstractArray{Bool}, vals, ::Type{AbstractDictionary}, length::Integer)
    ngroups = 0
    true_first = isempty(X) ? false : first(X)
    dct = isempty(X) ? ArrayDictionary(ArrayIndices(Bool[]), Int[]) : ArrayDictionary(ArrayIndices([true_first, !true_first]), [1, 2])

    rperm = _similar_1based(vals, length)
    i0 = 0
    i1 = length + 1
    @inbounds for (v, gid) in zip(vals, X)
        rperm[true_first ⊻ gid ? (i1 -= 1) : (i0 += 1)] = v
    end
    reverse!(view(rperm, 1:i0))

    i0 == length > 0 && delete!(dct, !true_first)
    starts = [0, i0, length]

    # dct: key -> group_id
    # rperm[starts[group_id + 1]:-1:1 + starts[group_id]] = group_values

    return (; dct, starts, rperm)
end

function _group_core_identity(X, vals, ::Type{DT}, length::Integer) where {DT}
    ngroups = 0
    groups = Vector{Int}(undef, length)
    dct = _default_concrete_dict(DT){_valtype(X), Int}()
    @inbounds for (i, x) in enumerate(X)
        groups[i] = gid = get!(dct, x, ngroups + 1)
        if gid == ngroups + 1
            ngroups += 1
        end
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

function _group_core_identity(X, vals, ::Type{DT}, ::Missing) where {DT}
    ngroups = 0
    groups = Int[]
    dct = _default_concrete_dict(DT){_valtype(X), Int}()
    @inbounds for (i, x) in enumerate(X)
        gid = get!(dct, x, ngroups + 1)
        push!(groups, gid)
        if gid == ngroups + 1
            ngroups += 1
        end
    end

    starts = zeros(Int, ngroups)
    @inbounds for gid in groups
        starts[gid] += 1
    end
    cumsum!(starts, starts)
    push!(starts, length(groups))

    rperm = _similar_1based(vals, length(groups))
    @inbounds for (v, gid) in zip(vals, groups)
        rperm[starts[gid]] = v
        starts[gid] -= 1
    end

    # dct: key -> group_id
    # rperm[starts[group_id + 1]:-1:1 + starts[group_id]] = group_values

    return (; dct, starts, rperm)
end

_default_concrete_dict(::Type{AbstractDict}) = Dict
_default_concrete_dict(::Type{AbstractDictionary}) = Dictionary
_default_concrete_dict(::Type{T}) where {T} = T

_similar_1based(vals::AbstractArray, length::Integer) = similar(vals, length)
_similar_1based(vals, length::Integer) = Vector{_eltype(vals)}(undef, length)
