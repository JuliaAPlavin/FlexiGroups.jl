"""    addmargins(dict; [combine=flatten])

Add margins to a `group` or `groupmap` result for all combinations of group key components.

For example, if a dataset is grouped by `a` and `b` (`keyf=x -> (;x.a, x.b)` in `group`), this adds groups for each `a` value and for each `b` value separately.

`combine` specifies how multiple groups are combined into margins. The default `combine=flatten` concatenates all relevant groups into a single collection.

# Examples
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
"""
function addmargins end

@generated function addmargins(dict::Dictionary{K, V}; combine=flatten) where {KS, K<:NamedTuple{KS}, V}
    dictexprs = map(combinations(reverse(KS))) do ks
        kf = :(_marginalize_key_func($(Val(Tuple(ks)))))
        :(merge!(res, _combine_groups_by($kf, dict, combine)))
    end
    KTs = map(combinations(KS)) do ks
        NamedTuple{KS, Tuple{[k ∈ ks ? Colon : fieldtype(K, k) for k in KS]...}}
    end
    quote
        KT = Union{$K, $(KTs...)}
        VT = Core.Compiler.return_type(combine, Tuple{Tuple{$V}})
        res = Dictionary{KT, VT}()
        merge!(res, map(combine ∘ tuple, dict))
        $(dictexprs...)
    end
end

function addmargins(dict::Dictionary{K, V}; combine=flatten) where {K, V}
    KT = Union{K, Colon}
    VT = Core.Compiler.return_type(combine, Tuple{Tuple{V}})
    res = Dictionary{KT, VT}()
    merge!(res, map(combine ∘ tuple, dict))
    merge!(res, _combine_groups_by(Returns(:), dict, combine))
end

_marginalize_key_func(::Val{ks_colon}) where {ks_colon} = key -> merge(key, NamedTuple{ks_colon}(ntuple(Returns(:), length(ks_colon))))

_combine_groups_by(kf, dict, combine) = @p begin
    keys(dict)
    groupfind(kf)
    map() do grixs
        combine(mapview(ix -> dict[ix], grixs))
    end
end

# could be defaults?
# for arrays/collections/iterables:
# _merge(vals) = flatten(vals)
# for onlinestats:
# _merge(vals) = reduce(merge!, vals; init=copy(first(vals)))
