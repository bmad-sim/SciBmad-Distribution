# Startup Configuration File
#
# This file runs after platform-specific arguments are set, allowing you to apply
# common startup options across all environments. Use this file to:
#   - Load development tools (e.g., Revise.jl for hot-reloading, Infiltrator.jl for debugging)
#   - Configure environment-specific settings
#   - Display diagnostic information about the Julia environment
#
# The diagnostic output below shows the active project, load paths, and depot paths
# to help verify your environment configuration.

if isdir(joinpath(last(DEPOT_PATH), "compiled/v$(VERSION.major).$(VERSION.minor)", "AppEnv")) || any(i -> i.name == "AppEnv", keys(Base.loaded_modules))
    import AppEnv
else
    include(joinpath(Sys.STDLIB, "AppEnv/src/AppEnv.jl"))
end
AppEnv.init()

if isnothing(Base.ACTIVE_PROJECT[])
    Base.ACTIVE_PROJECT[] = AppEnv.USER_DATA
end

if isinteractive()
    @async begin
        @eval using Revise

        @eval Base begin
            import Infiltrator: @infiltrate
            export @infiltrate
        end

        @eval import Pkg
        Base.invokelatest() do
            if isdefined(Pkg.Types, :FORMER_STDLIBS)
                empty!(Pkg.Types.FORMER_STDLIBS)
            elseif isdefined(Pkg.Types, :UPGRADABLE_STDLIBS)
                empty!(Pkg.Types.UPGRADABLE_STDLIBS)
            else
                @warn "Failed to clear upgradable stdlib list: neither FORMER_STDLIBS nor UPGRADABLE_STDLIBS found in Pkg.Types (Julia $VERSION)"
            end
        end
    end
end

# --- PythonCall ------------------------------------------------------------
# Left to itself, PythonCall asks CondaPkg to download and resolve a Python
# environment the first time it is loaded. That is the wait this distribution
# exists to avoid, and inside an installed bundle it cannot work at all: the
# install directory is read-only, so CondaPkg dies with
# `mkdir(".../.CondaPkg"): read-only file system`.
#
# Where Python_jll has a build for the platform, point PythonCall at the
# interpreter that ships inside the bundle and switch CondaPkg's environment
# management off, so `using PythonCall` costs about a second and touches
# neither the network nor the install directory.
#
# Python_jll is imported first on purpose: Python's `ctypes` module, which
# PythonCall's own `juliacall` package imports while initialising, needs libffi,
# and that lives in a different artifact from the interpreter. Importing the JLL
# loads its dependent libraries into the process so the interpreter can find
# them; without it, `using PythonCall` fails to dlopen libffi.
#
# Python_jll has no Windows build. There, let CondaPkg manage an environment in
# the user's writable data directory instead of inside the read-only bundle.
# That costs a one-time download on first use, but it works.
let
    try
        @eval import Python_jll
        if Base.invokelatest(Python_jll.is_available)
            get!(ENV, "JULIA_CONDAPKG_BACKEND", "Null")
            get!(ENV, "JULIA_PYTHONCALL_EXE", Python_jll.python_path)
            get!(ENV, "JULIA_PYTHONCALL_LIB", Python_jll.libpython_path)
        else
            get!(ENV, "JULIA_CONDAPKG_ENV", joinpath(AppEnv.USER_DATA, "python_env"))
        end
    catch err
        @warn "PythonCall is not configured; loading it may fail or try to install a Python environment." err
    end
end
