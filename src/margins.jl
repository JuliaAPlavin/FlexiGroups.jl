"""    addmargins(grouping; [combine=flatten])

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
    (a=1, b=total) => 1, (a=2, b=total) => 2, (a=3, b=total) => 3,  # margins for all values of a
    (a=total, b=:x) => 5, (a=total, b=:y) => 1,  # margins for all values of b
    (a=total, b=total) => 6,  # total
])
```
"""
function addmargins end

struct MarginKey end
const total = MarginKey()
Base.show(io::IO, ::MIME"text/plain", ::MarginKey) = print(io, "total")
Base.show(io::IO, ::MarginKey) = print(io, "total")


@generated function addmargins(dict::Dictionary{K, V}; combine=flatten, marginkey=total) where {KS, K<:NamedTuple{KS}, V}
    dictexprs = map(combinations(reverse(KS))) do ks
        kf = :(_marginalize_key_func($(Val(Tuple(ks))), marginkey))
        :(merge!(res, _combine_groups_by($kf, dict, combine)))
    end
    KTs = map(combinations(KS)) do ks
        NamedTuple{KS, Tuple{[k ∈ ks ? marginkey : fieldtype(K, k) for k in KS]...}}
    end
    quote
        KT = Union{$K, $(KTs...)}
        VT = Core.Compiler.return_type(combine, Tuple{Vector{$V}})
        res = Dictionary{KT, VT}()
        merge!(res, map(combine ∘ Base.vect, dict))
        $(dictexprs...)
    end
end

addmargins(dict::Dictionary{K, V}; combine=flatten, marginkey=total) where {N, K<:NTuple{N,Any}, V} =
    throw(ArgumentError("`addmargins()` is not implemented for Tuples as group keys. Use NamedTuples instead."))

function addmargins(dict::Dictionary{K, V}; combine=flatten, marginkey=total) where {K, V}
    KT = Union{K, typeof(marginkey)}
    VT = Core.Compiler.return_type(combine, Tuple{Vector{V}})
    res = Dictionary{KT, VT}()
    merge!(res, map(combine ∘ Base.vect, dict))
    merge!(res, _combine_groups_by(Returns(marginkey), dict, combine))
end

_marginalize_key_func(::Val{ks_colon}, marginkey) where {ks_colon} = key -> merge(key, NamedTuple{ks_colon}(ntuple(Returns(marginkey), length(ks_colon))))

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
