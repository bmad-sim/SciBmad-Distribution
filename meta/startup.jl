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
# Where Python_jll has a build for the platform, PythonCall is pointed at the
# interpreter that ships inside the bundle. That is done by a patch to
# PythonCall itself rather than from here (see `meta/patches` and the "Patches"
# section of README.md), because the build needs the same configuration: it
# precompiles packages that have PythonCall extensions, and compiling an
# extension loads its trigger packages -- running `PythonCall.__init__` in a
# worker process that never sees this file.
#
# Python_jll has no Windows build. There PythonCall resolves Python the usual
# way, so let CondaPkg manage an environment in the user's writable data
# directory instead of inside the read-only bundle. That costs a one-time
# download on first use, but it works.
if Sys.iswindows()
    get!(ENV, "JULIA_CONDAPKG_ENV", joinpath(AppEnv.USER_DATA, "python_env"))
end
