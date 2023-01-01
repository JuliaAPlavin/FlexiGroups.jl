module FlexiGroups

using Dictionaries
using Combinatorics: combinations
using FilterMaps: flatmap
using DataPipes

export group, groupview, groupfind, groupmap

include("base.jl")
include("margins.jl")



mapvalues(f, dict::AbstractDictionary) = map(f, dict)

function mapvalues(f, dict::Dict{K, VI}) where {K, VI}
    VO = Core.Compiler.return_type(f, Tuple{VI})
    vals = dict.vals
    newvals = similar(vals, VO)
    @inbounds for i in dict.idxfloor:lastindex(vals)
        if Base.isslotfilled(dict, i)
            newvals[i] = f(vals[i])
        end
    end
    _setproperties(dict, (;vals=newvals))
end

function _setproperties(d::Dict{K}, patch::NamedTuple{(:vals,), Tuple{AbstractVector{V}}}) where {K,V}
    @assert length(d.keys) == length(patch.vals)
    Dict{K,V}(copy(d.slots), copy(d.keys), patch.vals, d.ndel, d.count, d.age, d.idxfloor, d.maxprobe)
end


# make eltype tighter
_eltype(::T) where {T} = _eltype(T)
function _eltype(::Type{T}) where {T}
    ETb = eltype(T)
    ETb != Any && return ETb
    # Base.eltype returns Any for mapped/flattened/... iterators
    # here we attempt to infer a tighter type
    ET = Core.Compiler.return_type(first, Tuple{T})
    ET === Union{} ? Any : ET
end

_valtype(X) = _eltype(values(X))

end
