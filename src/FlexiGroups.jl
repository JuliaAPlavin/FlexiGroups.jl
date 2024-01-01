module FlexiGroups

using Dictionaries
using Combinatorics: combinations
using FlexiMaps: flatten, mapview, _eltype, Accessors
using DataPipes
using AccessorsExtra  # for values()

export
    group, groupview, groupfind, groupmap,
    group_vg, groupview_vg, groupfind_vg, groupmap_vg, Group, key, value,
    addmargins, MultiGroup, total

include("base.jl")
include("dictbacked.jl")
include("arraybacked.jl")
include("margins.jl")
include("grouptype.jl")

end
