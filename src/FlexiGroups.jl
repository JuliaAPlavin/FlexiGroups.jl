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
include("dictbacked.jl")
include("arraybacked.jl")
include("margins.jl")

end
