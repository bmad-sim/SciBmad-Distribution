# IJulia refuses to load unless this file exists: `src/IJulia.jl` opens with
#
#     isfile(depfile) || error("IJulia not properly installed. Please run Pkg.build(\"IJulia\")")
#     include(depfile)
#
# and the file is written by `Pkg.build("IJulia")`. AppBundler copies pristine package trees
# into the bundle and never runs `deps/build.jl`, so without this patch precompiling IJulia
# aborts the build. Supplying the generated file directly is enough -- the source needs no
# patching -- provided the two names it defines are given values that do not depend on the
# machine the bundle was built on. The stock `deps/build.jl` bakes in an absolute path to the
# Jupyter it found, which is exactly what must not happen here.
#
# `JUPYTER` is read in one place, `find_jupyter_subcommand` in `src/jupyter.jl`, and that
# function already special-cases the bare string "jupyter" to mean "look it up on PATH, and
# fall back to Conda's script directory". That is the runtime lookup this bundle wants, so
# the literal is the correct value rather than a placeholder. It also means `IJulia.notebook()`
# and `IJulia.jupyterlab()` work when the user has Jupyter on PATH and fail cleanly when they
# do not, instead of pointing at a path that never existed on their machine.
#
# `IJULIA_DEBUG` is read only as a default field value of the `Kernel` struct. `false` is what
# `deps/build.jl` writes whenever `IJULIA_DEBUG` is unset in the build environment, so this
# matches a stock build; as upstream, it is frozen at build time and not read from the
# environment at runtime.
    const IJULIA_DEBUG = false
    const JUPYTER = "jupyter"
