module FlexiGroups

using Dictionaries
using Combinatorics: combinations
using FlexiMaps: flatten, mapview, _eltype, Accessors
using DataPipes
using AccessorsExtra  # for values()

export
    group, groupview, groupfind, groupmap,
    addmargins, MultiGroup, total

include("base.jl")
include("arraybacked.jl")
include("margins.jl")

_valtype(X) = _eltype(values(X))

end
