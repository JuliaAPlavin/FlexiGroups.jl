module FlexiGroups

using Dictionaries
using Combinatorics: combinations
using FlexiMaps: FlexiMaps, flatten, mapview, _eltype, Accessors
using DataPipes
using AccessorsExtra  # for values()

export
    group, groupview, groupfind, groupmap,
    groups, groupviews, groupfinds, groupmaps,
    group_vg, groupview_vg, groupfind_vg, groupmap_vg,  # legacy aliases
    Group, key, value,
    addmargins, MultiGroup, total

include("base.jl")
include("dictbacked.jl")
include("arraybacked.jl")
include("margins.jl")
include("grouptype.jl")

end
