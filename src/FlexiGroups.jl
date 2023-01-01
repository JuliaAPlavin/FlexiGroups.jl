module FlexiGroups

using Dictionaries
using Combinatorics: combinations
using FlexiMaps: flatten, mapview, _eltype, Accessors
using DataPipes

export group, groupview, groupfind, groupmap

include("base.jl")
include("margins.jl")

using Requires
function __init__()
    @require AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5" include("ka.jl")
end


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

function _setproperties(d::Dict{K}, patch::NamedTuple{(:vals,), <:Tuple{AbstractVector{V}}}) where {K,V}
    @assert length(d.keys) == length(patch.vals)
    Dict{K,V}(copy(d.slots), copy(d.keys), patch.vals, d.ndel, d.count, d.age, d.idxfloor, d.maxprobe)
end


_valtype(X) = _eltype(values(X))

end
