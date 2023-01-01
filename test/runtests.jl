using TestItems
using TestItemRunner
@run_package_tests


@testitem "basic" begin
    using Dictionaries

    xs = 3 .* [1, 2, 3, 4, 5]
    g = @inferred group(isodd, xs)
    @test g == dictionary([true => [3, 9, 15], false => [6, 12]])
    @test isconcretetype(eltype(g))
    @test valtype(g) <: SubArray{Int}

    # ensure we get a copy
    xs[1] = 123
    @test g == dictionary([true => [3, 9, 15], false => [6, 12]])


    xs = 3 .* [1, 2, 3, 4, 5]
    g = @inferred groupview(isodd, xs)
    @test g == dictionary([true => [3, 9, 15], false => [6, 12]])
    @test isconcretetype(eltype(g))
    @test valtype(g) <: SubArray{Int}

    # ensure we get a view
    xs[1] = 123
    @test g == dictionary([true => [123, 9, 15], false => [6, 12]])


    xs = 3 .* [1, 2, 3, 4, 5]
    g = @inferred groupfind(isodd, xs)
    @test g == dictionary([true => [1, 3, 5], false => [2, 4]])
    @test isconcretetype(eltype(g))
    @test valtype(g) <: SubArray{Int}


    g = @inferred(group(isnothing, [1, 2, 3, nothing, 4, 5, nothing]))
    @test g == dictionary([false => [1, 2, 3, 4, 5], true => [nothing, nothing]])
    @test valtype(g) <: SubArray{Union{Nothing, Int}}
end

@testitem "margins" begin
    using FlexiGroups: addmargins
    using Dictionaries
    using StructArrays

    xs = [(a=1, b=:x), (a=2, b=:x), (a=2, b=:y), (a=3, b=:x), (a=3, b=:x), (a=3, b=:x)]
    g = @inferred group(x -> x, xs)
    @test map(length, g) == dictionary([(a=1, b=:x) => 1, (a=2, b=:x) => 1, (a=2, b=:y) => 1, (a=3, b=:x) => 3])

    gm = addmargins(g)
    @test map(length, gm) == dictionary([
        (a=1, b=:x) => 1, (a=2, b=:x) => 1, (a=2, b=:y) => 1, (a=3, b=:x) => 3,
        (a=1, b=:) => 1, (a=2, b=:) => 2, (a=3, b=:) => 3,
        (a=:, b=:x) => 5, (a=:, b=:y) => 1,
        (a=:, b=:) => 6,
    ])
    @test keytype(gm) isa Union  # of NamedTuples
    @test valtype(gm) |> isconcretetype
    @test valtype(gm) == Vector{NamedTuple{(:a, :b), Tuple{Int64, Symbol}}}

    g = @inferred group(x -> x, StructArray(xs))
    gm = addmargins(g)
    @test map(length, gm) == dictionary([
        (a=1, b=:x) => 1, (a=2, b=:x) => 1, (a=2, b=:y) => 1, (a=3, b=:x) => 3,
        (a=1, b=:) => 1, (a=2, b=:) => 2, (a=3, b=:) => 3,
        (a=:, b=:x) => 5, (a=:, b=:y) => 1,
        (a=:, b=:) => 6,
    ])
    @test keytype(gm) isa Union  # of NamedTuples
    @test_broken valtype(gm) |> isconcretetype  # https://github.com/JuliaArrays/StructArrays.jl/issues/247
    @test valtype(gm) == StructVector{NamedTuple{(:a, :b), Tuple{Int64, Symbol}}}
end

@testitem "groupmap" begin
    using Dictionaries

    xs = 3 .* [1, 2, 3, 4, 5]
    for f in [length, first, last]
        @test @inferred(groupmap(isodd, f, xs)) == map(f, group(isodd, xs))
    end
    @test all(@inferred(groupmap(isodd, rand, xs)) .∈ group(isodd, xs))
    @test_throws "exactly one element" groupmap(isodd, only, xs)
    @test @inferred(groupmap(isodd, only, [10, 11])) == dictionary([false => 10, true => 11])
end

@testitem "iterators" begin
    using Dictionaries

    xs = (3x for x in [1, 2, 3, 4, 5])
    g = @inferred group(isodd, xs)
    @test g == dictionary([true => [3, 9, 15], false => [6, 12]])
    @test isconcretetype(eltype(g))
    @test valtype(g) <: SubArray{Int}
end

@testitem "dicttypes" begin
    using Dictionaries

    @testset for D in [Dict, Dictionary, UnorderedDictionary, ArrayDictionary]
        @test group(isodd, 3 .* [1, 2, 3, 4, 5]; dicttype=D) |> pairs |> Dict == Dict(false => [6, 12], true => [3, 9, 15])
        @test group(isodd, (3x for x in [1, 2, 3, 4, 5]); dicttype=D) |> pairs |> Dict == Dict(false => [6, 12], true => [3, 9, 15])
    end
end

@testitem "structarray" begin
    using Dictionaries
    using StructArrays

    xs = StructArray(a=3 .* [1, 2, 3, 4, 5])
    g = @inferred group(x -> isodd(x.a), xs)
    @test g == dictionary([true => [(a=3,), (a=9,), (a=15,)], false => [(a=6,), (a=12,)]])
    @test isconcretetype(eltype(g))
    @test g[false].a == [6, 12]

    g = @inferred groupview(x -> isodd(x.a), xs)
    @test g == dictionary([true => [(a=3,), (a=9,), (a=15,)], false => [(a=6,), (a=12,)]])
    @test isconcretetype(eltype(g))
    @test g[false].a == [6, 12]
end

@testitem "keyedarray" begin
    using Dictionaries
    using AxisKeys

    xs = KeyedArray(1:5, a=3 .* [1, 2, 3, 4, 5])
    g = @inferred group(isodd, xs)
    @test g == dictionary([true => [1, 3, 5], false => [2, 4]])
    @test isconcretetype(eltype(g))
    @test_broken axiskeys(g[false]) == ([6, 12],)
    @test_broken g[false](a=6) == 2

    g = @inferred groupview(isodd, xs)
    @test g == dictionary([true => [1, 3, 5], false => [2, 4]])
    @test isconcretetype(eltype(g))
    @test axiskeys(g[false]) == ([6, 12],)
    @test g[false](a=6) == 2
end

@testitem "offsetarrays" begin
    using Dictionaries
    using OffsetArrays

    xs = OffsetArray(1:5, 10)
    g = @inferred group(isodd, xs)
    @test g::Dictionary{Bool, <:AbstractVector{Int}} == dictionary([true => [1, 3, 5], false => [2, 4]])
    @test isconcretetype(eltype(g))

    g = @inferred groupview(isodd, xs)
    @test g::Dictionary{Bool, <:AbstractVector{Int}} == dictionary([true => [1, 3, 5], false => [2, 4]])
    @test isconcretetype(eltype(g))

    g = @inferred groupmap(isodd, length, xs)
    @test g::Dictionary{Bool, Int} == dictionary([true => 3, false => 2])
end

@testitem "pooledarray" begin
    using PooledArrays
    using StructArrays
    using Dictionaries

    xs = PooledArray([i for i in 1:255], UInt8)
    @test groupmap(isodd, length, xs) == dictionary([true => 128, false => 127])

    sa = StructArray(a=PooledArray(repeat(1:255, outer=100), UInt8), b=1:255*100)
    @test all(==(100), groupmap(x -> x.a, length, sa))
    @test all(==(1), groupmap(x -> x.b, length, sa))
    @test all(==(1), map(length, group(x -> (x.a, x.b), sa)))
end

@testitem "typedtable" begin
    using Dictionaries
    using TypedTables

    xs = Table(a=3 .* [1, 2, 3, 4, 5])
    g = @inferred group(x -> isodd(x.a), xs)
    @test g == dictionary([true => [(a=3,), (a=9,), (a=15,)], false => [(a=6,), (a=12,)]])
    @test isconcretetype(eltype(g))
    @test g[false].a == [6, 12]

    g = @inferred groupview(x -> isodd(x.a), xs)
    @test g == dictionary([true => [(a=3,), (a=9,), (a=15,)], false => [(a=6,), (a=12,)]])
    @test isconcretetype(eltype(g))
    @test g[false].a == [6, 12]
end

@testitem "dictionary" begin
    using Dictionaries
    # view(dct, range) doesn't work for dictionaries by default
    Base.view(d::AbstractDictionary, inds::AbstractArray) = Dictionaries.ViewArray{valtype(d), ndims(inds)}(d, inds)

    xs = dictionary(3 .* [1, 2, 3, 4, 5] .=> 1:5)
    g = @inferred group(isodd, xs)
    @test g == dictionary([true => [1, 3, 5], false => [2, 4]])
    @test isconcretetype(eltype(g))
    @test g[false] == [2, 4]

    g = @inferred groupview(isodd, xs)
    @test g == dictionary([true => [1, 3, 5], false => [2, 4]])
    @test isconcretetype(eltype(g))
    @test g[false] == [2, 4]
    xs[6] = 123
    @test g == dictionary([true => [1, 3, 5], false => [123, 4]])
end

@testitem "skipper" begin
    using Skipper
    using Dictionaries

    g = group(isodd, skip(isnothing, [1., 2, nothing, 3]))
    @test g == dictionary([true => [1, 3], false => [2]])
    @test g isa Dictionary{Bool, <:SubArray{Float64}}

    g = group(isodd, skip(isnan, [1, 2, NaN, 3]))
    @test g == dictionary([true => [1, 3], false => [2]])
    @test g isa Dictionary{Bool, <:SubArray{Float64}}

    g = groupfind(isodd, skip(isnan, [1, 2, NaN, 3]))
    @test g == dictionary([true => [1, 4], false => [2]])
    @test g isa Dictionary{Bool, <:SubArray{Int}}
end

@testitem "_" begin
    import Aqua
    Aqua.test_all(FlexiGroups; ambiguities=false)
    Aqua.test_ambiguities(FlexiGroups)

    import CompatHelperLocal as CHL
    CHL.@check()
end
