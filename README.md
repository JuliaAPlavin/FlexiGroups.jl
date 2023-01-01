# FlexiGroups.jl

Arrange tabular or non-tabular datasets into groups according to a specified key function.

## `group`/`groupview`/`groupmap`

`group([keyf=identity], X; [restype=Dictionary])`: group elements of `X` by `keyf(x)`, returning a mapping `keyf(x)` values to lists of `x` values in each group.

The result is an (ordered) `Dictionary` by default, but can be specified to be a base `Dict` as well.

Alternatively to dictionaries, specifying `restype=KeyedArray` (from `AxisKeys.jl`) results in a `KeyedArray`. Its `axiskeys` are the group keys.

```julia
xs = 3 .* [1, 2, 3, 4, 5]
g = group(isodd, xs)
g == dictionary([true => [3, 9, 15], false => [6, 12]])


g = group(x -> (a=isodd(x),), xs; restype=KeyedArray)
g == KeyedArray([[6, 12], [3, 9, 15]]; a=[false, true])
```

`groupview([keyf=identity], X; [restype=Dictionary])`: like the `group` function, but each group is a `view` of `X` and doesn't copy the input elements.

`groupmap([keyf=identity], mapf, X; [restype=Dictionary])`: like `map(mapf, group(keyf, X))`, but more efficient. Supports a limited set of `mapf` functions: `length`, `first`/`last`, `only`, `rand`.

# Margins

`addmargins(dict; [combine=flatten])`: add margins to a `group` or `groupmap` result for all combinations of group key components.

For example, if a dataset is grouped by `a` and `b` (`keyf=x -> (;x.a, x.b)` in `group`), this adds groups for each `a` value and for each `b` value separately.

`combine` specifies how multiple groups are combined into margins. The default `combine=flatten` concatenates all relevant groups into a single collection.

```julia
xs = [(a=1, b=:x), (a=2, b=:x), (a=2, b=:y), (a=3, b=:x), (a=3, b=:x), (a=3, b=:x)]
# basic grouping by unique combinations of a and b
g = group(xs)
map(length, g) == dictionary([(a=1, b=:x) => 1, (a=2, b=:x) => 1, (a=2, b=:y) => 1, (a=3, b=:x) => 3])

# add margins
gm = addmargins(g)
map(length, gm) == dictionary([
    (a=1, b=:x) => 1, (a=2, b=:x) => 1, (a=2, b=:y) => 1, (a=3, b=:x) => 3,  # original grouping result
    (a=1, b=:) => 1, (a=2, b=:) => 2, (a=3, b=:) => 3,  # margins for all values of a
    (a=:, b=:x) => 5, (a=:, b=:y) => 1,  # margins for all values of b
    (a=:, b=:) => 6,  # total
])
```
