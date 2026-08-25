using Pkg

Pkg.activate(normpath(joinpath(@__DIR__, "..")))
Pkg.test()
