using BinDeps
using Conda

@BinDeps.setup

libeccodes = library_dependency("libeccodes")
Conda.add_channel("conda-forge")
Conda.update() 
provides(Conda.Manager, Dict("eccodes"=>libeccodes))

@BinDeps.install Dict(:libeccodes => :libeccodes)
