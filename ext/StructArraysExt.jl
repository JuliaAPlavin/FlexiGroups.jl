module StructArraysExt

using StructArrays
import FlexiGroups: _possible_values

function _possible_values(X::StructArray{<:Tuple})
    vals = map(_possible_values, StructArrays.components(X))
    any(isnothing, vals) ? nothing : Iterators.product(vals...)
end

function _possible_values(X::StructArray{<:NamedTuple{KS}}) where {KS}
    vals = map(_possible_values, StructArrays.components(X))
    any(isnothing, vals) ? nothing : NamedTuple{KS}.(Iterators.product(vals...))
end

end
