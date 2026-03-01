module CategoricalArraysExt
using CategoricalArrays
import FlexiGroups: _possible_values

_possible_values(X::CategoricalArray) = CategoricalArrays.unwrap.(levels(X))
_possible_values(X::AbstractArray{<:CategoricalValue}) = isempty(X) ? nothing : CategoricalArrays.unwrap.(levels(first(X)))

end
