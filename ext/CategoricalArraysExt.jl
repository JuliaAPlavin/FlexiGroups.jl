module CategoricalArraysExt
using CategoricalArrays
import FlexiGroups: _possible_values

_possible_values(X::CategoricalArray) = levels(X)
_possible_values(X::AbstractArray{<:CategoricalValue}) = isempty(X) ? nothing : levels(first(X))

end
