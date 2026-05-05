# FlexiGroups.jl

Arrange tabular or non-tabular datasets into groups according to a specified key function.

The main principle of `FlexiGroups` is that the result of a grouping operation is always a collection of groups, and each group is a collection of elements. Groups are typically indexed by the grouping key.

## Two families: lookup vs sequence

The eight grouping functions form a 4×2 grid: four operations crossed with two output shapes.

| Operation | Lookup form (key-indexed)              | Sequence form (`Vector{Group}`) |
|-----------|----------------------------------------|---------------------------------|
| Group     | `group(keyf, X)`                       | `groups(keyf, X)`               |
| View      | `groupview(keyf, X)`                   | `groupviews(keyf, X)`           |
| Indices   | `groupfind(keyf, X)`                   | `groupfinds(keyf, X)`           |
| Reduce    | `groupmap(keyf, mapf, X)`              | `groupmaps(keyf, mapf, X)`      |

The **lookup form** returns a `Dictionary` (default) you index by group key: `g[k]`. The **sequence form** returns a `Vector{Group}` (or `StructVector{Group}` when the input is a `StructArray`) where each element bundles its key — useful for flatmap-style pipelines and tabular workflows.

```julia
xs = 3 .* [1, 2, 3, 4, 5]
g = group(isodd, xs)
# g == dictionary([true => [3, 9, 15], false => [6, 12]]) from Dictionaries.jl

gs = groups(isodd, xs)
# gs == [Group(true, [3, 9, 15]), Group(false, [6, 12])]
```

The lookup form accepts an `into=` keyword to switch storage:

| `into=`         | Result                                | Constraint on key                |
|-----------------|---------------------------------------|----------------------------------|
| `Dictionary`    | ordered Dictionaries.jl `Dictionary`  | any                              |
| `Dict`          | base hashmap                          | any                              |
| `KeyedArray`    | N-D axis-keyed array (AxisKeys.jl)    | `NamedTuple` or `Tuple`          |
| `Vector`        | dense 1-D positional                  | `Int`, dense from `1`            |
| `OffsetVector`  | dense 1-D positional, offset          | contiguous `Int` range           |

```julia
g = group(x -> (a=isodd(x),), xs; into=KeyedArray)
# g == KeyedArray([[6, 12], [3, 9, 15]]; a=[false, true])
```

`groupmap(keyf, mapf, X)` is `map(mapf, group(keyf, X))` fused. It supports a limited set of `mapf` functions: `length`, `first`, `last`, `only`, `rand`. For arbitrary `mapf`, use `map(mapf, groupview(keyf, X))` — efficient because `groupview` returns `SubArray`s.

# Margins

`addmargins(dict; [combine=flatten])`: add margins to a grouping for all combinations of group key components.

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
    (a=1, b=total) => 1, (a=2, b=total) => 2, (a=3, b=total) => 3,  # margins for all values of a
    (a=total, b=:x) => 5, (a=total, b=:y) => 1,  # margins for all values of b
    (a=total, b=total) => 6,  # total
])
```

# More examples

Compute the fraction of elements in each group:
```julia
julia> using FlexiGroups, DataPipes

julia> x = rand(1:100, 100);

julia> @p x |>
       groupmap(_ % 3, length) |>  # group by x % 3 and compute length of each group
       FlexiGroups.addmargins(combine=sum) |>  # append the margin - here, the total of all group lengths
       __ ./ __[total]  # divide lengths by that total
4-element Dictionaries.Dictionary{Union{Colon, Int64}, Float64}
       2 │ 0.34
       0 │ 0.33
       1 │ 0.33
   total │ 1.0
```

Perform per-group computations and combine into a single flat collection:
```julia
julia> using FlexiGroups, FlexiMaps, DataPipes, StructArrays

julia> x = rand(1:100, 10)
10-element Vector{Int64}:
 70
 57
 57
 69
 61
 74
 31
 39
 48
 96

# regular flatmap: puts all elements of the first group first, then the second, and so on
# the resulting order is different from the original `x` above
julia> @p x |>
       groupview(_ % 3) |>
       flatmap(StructArray(x=_, ind_in_group=eachindex(_)))
10-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype NamedTuple{(:x, :ind_in_group), Tuple{Int64, Int64}}:
 (x = 70, ind_in_group = 1)
 (x = 61, ind_in_group = 2)
 (x = 31, ind_in_group = 3)
 (x = 57, ind_in_group = 1)
 (x = 57, ind_in_group = 2)
 (x = 69, ind_in_group = 3)
 (x = 39, ind_in_group = 4)
 (x = 48, ind_in_group = 5)
 (x = 96, ind_in_group = 6)
 (x = 74, ind_in_group = 1)

# flatmap_parent: puts elements in the same order as they were in the parent `x` array above
julia> @p x |>
       groupview(_ % 3) |>
       flatmap_parent(StructArray(x=_, ind_in_group=eachindex(_)))
10-element StructArray(::Vector{Int64}, ::Vector{Int64}) with eltype NamedTuple{(:x, :ind_in_group), Tuple{Int64, Int64}}:
 (x = 70, ind_in_group = 1)
 (x = 57, ind_in_group = 1)
 (x = 57, ind_in_group = 2)
 (x = 69, ind_in_group = 3)
 (x = 61, ind_in_group = 2)
 (x = 74, ind_in_group = 1)
 (x = 31, ind_in_group = 3)
 (x = 39, ind_in_group = 4)
 (x = 48, ind_in_group = 5)
 (x = 96, ind_in_group = 6)
```

Pivot tables:
```julia
julia> using FlexiGroups, DataPipes, StructArrays, AxisKeys

# generate a simple table
julia> x = @p rand(1:100, 100) |> map((value=_, mod3=_ % 3, mod5=_ % 5)) |> StructArray
100-element StructArray(::Vector{Int64}, ::Vector{Int64}, ::Vector{Int64}) with eltype NamedTuple{(:value, :mod3, :mod5), Tuple{Int64, Int64, Int64}}:
 (value = 29, mod3 = 2, mod5 = 4)
 (value = 93, mod3 = 0, mod5 = 3)
 (value = 1, mod3 = 1, mod5 = 1)
 (value = 57, mod3 = 0, mod5 = 2)
 (value = 2, mod3 = 2, mod5 = 2)
 ⋮

# compute sum of `value`s grouped by `mod3` and `mod5`
julia> @p x |>
       group((; _.mod3, _.mod5); into=KeyedArray) |>
       map(sum(_.value))
2-dimensional KeyedArray(NamedDimsArray(...)) with keys:
↓   mod3 ∈ 3-element Vector{Int64}
→   mod5 ∈ 5-element Vector{Int64}
And data, 3×5 Matrix{Int64}:
      (0)  (1)  (2)  (3)  (4)
 (0)  390  372  378  258  225
 (1)  480  247  372  187  362
 (2)  475   82  352  318  203
```

# Alternatives

- `SplitApplyCombine.jl` also provides `group` and `groupview` functions with similar basic semantics. Notable differences of `FlexiGroups` include:
  - margins support;
  - more flexibility in the return container type - various dictionaries, keyed arrays;
  - group collection type is the same as the input collection type, when possible; for example, grouping a `StructArray`s results in each group also being a `StructArray`;
  - better return eltype and type inference;
  - often performs faster and with fewer allocations.
