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
const BASERESTYPES = Union{DICTS, AbstractVector}

struct GroupValues end
struct GroupValue end
Accessors.modify(f, obj, ::GroupValues) = @modify(f, values(obj)[∗] |> GroupValue())
Accessors.modify(f, obj, ::GroupValue) = f(obj)

function _groupfind(f::F, X, ::Type{RT}) where {F, RT <: BASERESTYPES}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(dct |> GroupValues()) do gid
        @view rperm[starts[gid]:starts[gid + 1]-1]
    end
end

function _groupview(f::F, X, ::Type{RT}) where {F, RT <: BASERESTYPES}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(dct |> GroupValues()) do gid
        ix = @view rperm[starts[gid]:starts[gid + 1]-1]
        @view X[ix]
    end
end

function _group(f::F, X, ::Type{RT}) where {F, RT <: BASERESTYPES}
    (; dct, starts, rperm) = _group_core(f, X, X, RT)
    res = @modify(dct |> GroupValues()) do gid
        @inline
        @view rperm[starts[gid]:starts[gid + 1]-1]
    end
end

function _groupmap(f::F, ::typeof(length), X, ::Type{RT}) where {F, RT <: BASERESTYPES}
    vals = map(Returns(nothing), X)
    (; dct, starts, rperm) = _group_core(f, X, vals, RT)
    @modify(dct |> GroupValues()) do gid
        starts[gid + 1] - starts[gid]
    end
end

function _groupmap(f::F, ::typeof(first), X, ::Type{RT}) where {F, RT <: BASERESTYPES}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(dct |> GroupValues()) do gid
        ix = rperm[starts[gid]]
        X[ix]
    end
end

function _groupmap(f::F, ::typeof(last), X, ::Type{RT}) where {F, RT <: BASERESTYPES}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(dct |> GroupValues()) do gid
        ix = rperm[starts[gid + 1] - 1]
        X[ix]
    end
end

function _groupmap(f::F, ::typeof(only), X, ::Type{RT}) where {F, RT <: BASERESTYPES}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(dct |> GroupValues()) do gid
        starts[gid + 1] == starts[gid] + 1 || throw(ArgumentError("groupmap(only, X) requires that each group has exactly one element"))
        ix = rperm[starts[gid]]
        X[ix]
    end
end

function _groupmap(f::F, ::typeof(rand), X, ::Type{RT}) where {F, RT <: BASERESTYPES}
    (; dct, starts, rperm) = _group_core(f, X, keys(X), RT)
    @modify(dct |> GroupValues()) do gid
        ix = rperm[rand(starts[gid]:starts[gid + 1]-1)]
        X[ix]
    end
end


_group_core(f::F, X::AbstractArray, vals, dicttype) where {F} = _group_core(f, X, vals, dicttype, length(X))
_group_core(f::F, X, vals, dicttype) where {F} = _group_core(f, X, vals, dicttype, Base.IteratorSize(X) isa Base.SizeUnknown ? missing : length(X))
_group_core(f::F, X, vals, dicttype, length) where {F} = _group_core_identity(mapview(f, X), vals, dicttype, length)

# XXX: are these specializations useful? seemed to be, before adding ::F specialization to higher-level group...() funcs
# __precompile__(false)
# @eval AccessorsExtra modify(f::F, obj::KVPWrapper{typeof(values)}, ::Elements) where {F} = map(f, obj.obj)
# @eval Dictionaries function Base.map(f::F, d::AbstractDictionary) where {F}
#     out = similar(d, Core.Compiler.return_type(f, Tuple{eltype(d)}))
#     @inbounds map!(f, out, d)
#     return out
# end

if VERSION < v"1.10-"
    _similar_1based(vals::AbstractArray, len::Integer) = similar(vals, len)
    _similar_1based(vals, len::Integer) = Vector{_eltype(vals)}(undef, len)
else
    # applicable() is compiletime in 1.10+
    _similar_1based(vals, len::Integer) = applicable(similar, vals, len) ? similar(vals, len) : Vector{_eltype(vals)}(undef, len)
end
