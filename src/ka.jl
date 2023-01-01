using .AxisKeys

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

@generated function _group_dict_to_ka(gd::Dictionary{K, V}, default::D, ::Type{KeyedArray}) where {K, V, D}
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
            # searchsorted relies on sort above
            ixs = map(only ∘ searchsorted, axkeys, k)
            data[ixs...] = v
        end

        A = KeyedArray(data; axkeys...)

        return A
    end
end

using FlexiMaps.Accessors

function addmargins(A::KeyedArray; combine=flatten, marginkey=total)
    if ndims(A) == 1
        nak = named_axiskeys(A)
        nak_ = @modify(only(nak)) do ax
            Union{eltype(ax), typeof(marginkey)}[marginkey]
        end
        m = KeyedArray([combine(A)]; nak_...)
        return cat(A, m; dims=1)
    else
        res = A
        alldims = Tuple(1:ndims(A))
        allones = ntuple(Returns(1), ndims(A))
        allcolons = map(ax -> Union{eltype(ax), typeof(marginkey)}[marginkey], named_axiskeys(A))
        for i in 1:ndims(A)
            nak = @set allcolons[i] = named_axiskeys(res)[i]
            m = @p let
                eachslice(res; dims=i)
                map(combine)
                reshape(__, @set allones[i] = :)
                KeyedArray(__; nak...)
            end 
            res = cat(res, m; dims=@delete alldims[i])
        end
        return res
    end
end
