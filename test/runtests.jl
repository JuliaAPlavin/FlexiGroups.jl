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

@testitem "groupmap" begin
    using Dictionaries

    xs = 3 .* [1, 2, 3, 4, 5]
    @test @inferred(groupmap(isodd, length, xs)) == dictionary([true => 3, false => 2])
    @test @inferred(groupmap(isodd, first, xs)) == dictionary([true => 3, false => 6])
    @test @inferred(groupmap(isodd, last, xs)) == dictionary([true => 15, false => 12])
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

@testitem "dicttypes"
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

@testitem "_" begin
    import Aqua
    Aqua.test_all(FlexiGroups; ambiguities=false)
    Aqua.test_ambiguities(FlexiGroups)

    import CompatHelperLocal as CHL
    CHL.@check()
end
