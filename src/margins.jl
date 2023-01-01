@generated function addmargins(dict::Dictionary{K, V}) where {KS, K<:NamedTuple{KS}, V}
    dictexprs = map(combinations(reverse(KS))) do ks
        kf = :(_marginalize_key_func($(Val(Tuple(ks)))))
        :(merge!(res, _combine_groups_by($kf, dict)))
    end
    KTs = map(combinations(KS)) do ks
        NamedTuple{KS, Tuple{[k ∈ ks ? Colon : fieldtype(K, k) for k in KS]...}}
    end
    quote
        KT = Union{$K, $(KTs...)}
        VT = Core.Compiler.return_type(vcat, Tuple{$V})
        res = Dictionary{KT, VT}()
        merge!(res, dict)
        $(dictexprs...)
    end
end

_marginalize_key_func(::Val{ks_colon}) where {ks_colon} = key -> merge(key, NamedTuple{ks_colon}(ntuple(Returns(:), length(ks_colon))))

_combine_groups_by(kf, dict) = @p begin
    keys(dict)
    groupfind(kf)
    map() do grixs
        flatmap(ix -> dict[ix], grixs)
    end
end
