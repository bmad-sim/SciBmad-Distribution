# Conda is a dependency of IJulia and fails the same way IJulia does without a generated
# `deps/deps.jl` -- `src/Conda.jl` errors with "Conda is not properly configured. Run
# Pkg.build(\"Conda\")". It is pulled into the bundle whether or not anything calls it, so it
# has to precompile even though a read-only install can never manage a Conda environment.
#
# The four names below are the ones `deps/build.jl` writes, with its own default values:
# Miniconda 3, Miniforge on every architecture the bundle targets (`build.jl` only turns it
# off for 32-bit x86, which is not among them), a root environment under the depot, and the
# conda executable inside it. Computing them here rather than hardcoding strings keeps the
# build machine's depot path out of the file, though `Conda.ROOTENV` and the paths derived
# from it are still `const` and so are still frozen at precompile time -- inside the
# installed bundle they point at the staging depot, which no longer exists. Nothing in the
# distribution calls Conda, so that is latent rather than a fault: the one path that reaches
# it is `IJulia.notebook()`, which reads `Conda.SCRIPTDIR` only as a fallback after
# `Sys.which("jupyter")` has already failed.
#
# The `mkpath` is load bearing. `src/Conda.jl` computes `const PREFIX = prefix(ROOTENV)` at
# precompile time, and `prefix(::AbstractString)` throws `ArgumentError: Path to conda
# environment is not valid` unless the directory is already there. `Pkg.build("Conda")`
# creates it as a side effect; since that never runs here, this file has to.
    const MINICONDA_VERSION = "3"
    const USE_MINIFORGE = true
    const ROOTENV = get(ENV, "CONDA_JL_HOME",
                        joinpath(first(DEPOT_PATH), "conda", MINICONDA_VERSION, string(Sys.ARCH)))
    const CONDA_EXE = Sys.iswindows() ? joinpath(ROOTENV, "Scripts", "conda.exe") :
                                        joinpath(ROOTENV, "bin", "conda")
    mkpath(ROOTENV)
