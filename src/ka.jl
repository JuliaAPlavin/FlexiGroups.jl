for f in (:_group, :_groupview, :_groupfind)
    @eval function $f(f, xs, ::Type{TA}; default=undef) where {TA <: AbstractArray}
        gd = $f(f, xs, Dictionary)
        _group_dict_to_ka(gd, default, TA)
    end
end

function _groupmap(f, mapf, xs, ::Type{TA}; default=undef) where {TA <: AbstractArray}
    gd = _groupmap(f, mapf, xs, Dictionary)
    _group_dict_to_ka(gd, default, TA)
end

@generated function _group_dict_to_ka(gd::Dictionary{K, V}, default::D, ::Type{TA}) where {K, V, D, TA}
    @assert nameof(TA) == :KeyedArray
    axkeys_exprs = map(fieldnames(K)) do n
        col = :( map(Accessors.PropertyLens{$(QuoteNode(n))}(), keys(gd).values) |> unique |> sort )
    end
    quote
        axkeys = NamedTuple{$(fieldnames(K))}(($(axkeys_exprs...),))

        vals = gd.values
        sz = map(length, values(axkeys))
        if default === undef
            data = similar(vals, sz)
        else
            data = similar(vals, $(Union{V, D}), sz)
            fill!(data, default)
        end

        for (k, v) in pairs(gd)
            ixs = map(only ∘ searchsorted, axkeys, k)
            data[ixs...] = v
        end

        A = $TA(data; axkeys...)

        return A
    end
end
