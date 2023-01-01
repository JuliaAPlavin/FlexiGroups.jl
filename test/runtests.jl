using TestItems
using TestItemRunner
@run_package_tests


@testitem "_" begin
    import Aqua
    Aqua.test_all(FlexiGroups; ambiguities=false)
    Aqua.test_ambiguities(FlexiGroups)

    import CompatHelperLocal as CHL
    CHL.@check()
end
