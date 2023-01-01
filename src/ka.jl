function _group(f, xs, ::Type{TA}; default=undef) where {TA <: AbstractArray}
    @assert nameof(TA) == :KeyedArray
    gd = group(f, xs)
    _group_dict_to_ka(gd, default, TA)
end

function _groupmap(f, mapf, X, ::Type{TA}; default=undef) where {TA <: AbstractArray}
    @assert nameof(TA) == :KeyedArray
    gd = groupmap(f, mapf, X)
    _group_dict_to_ka(gd, default, TA)
end

@generated function _group_dict_to_ka(gd::Dictionary{K, V}, default::D, ::Type{TA}) where {K, V, D, TA}
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
        A = $TA(data; axkeys...)

        for (k, v) in pairs(gd)
            # inds = map(AxisKeys.findindex, k, axkeys)
            # setindex!(A, v, inds...)
            A(:; k...) .= Ref(v)
        end

        return A
    end
end
