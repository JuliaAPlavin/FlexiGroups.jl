using .AxisKeys

export groupka

function groupka(f, xs; default=undef)
    gd = group(f, xs)
    _group_dict_to_ka(gd, default)
end

@generated function _group_dict_to_ka(gd::Dictionary{K, V}, default::D) where {K, V, D}
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
        A = KeyedArray(data; axkeys...)

        for (k, v) in pairs(gd)
            inds = map(AxisKeys.findindex, k, axiskeys(A))
            setindex!(A, v, inds...)
        end

        return A
    end
end
