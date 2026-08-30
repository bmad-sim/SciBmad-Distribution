# Startup Configuration File
#
# This file runs after platform-specific arguments are set, allowing you to apply
# common startup options across all environments. Use this file to:
#   - Load development tools (e.g., Infiltrator.jl for debugging)
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
# Two platforms get no bundled interpreter: Windows, which Python_jll does not
# build for, and macOS x86_64, whose build is broken (the patch explains how).
# There PythonCall falls back to CondaPkg, which needs two things arranged for
# it.
#
# First, somewhere writable to put the environment -- inside the read-only
# bundle CondaPkg dies with `mkdir(".../.CondaPkg"): read-only file system`.
#
# Second, something that tells it to install Python at all. CondaPkg works that
# out by walking the projects on the load path and reading the `CondaPkg.toml`
# of every package it finds, and inside a bundle that walk comes up empty:
# `Pkg.dependencies()` reports each package's source as a path in the user's
# depot, where nothing was ever unpacked, so PythonCall's own `CondaPkg.toml` is
# never read and CondaPkg creates an environment with nothing in it. PythonCall
# then fails with `Python executable ".../bin/python" does not exist`. The
# user's data directory is the active project, and CondaPkg reads the active
# project's own `CondaPkg.toml` directly, without resolving anything -- so
# declaring the interpreter there is enough. Both files are only created when
# absent, so anything the user adds later with `CondaPkg.add` survives.
#
# The version bound is PythonCall v0.9.35's own; keep it in step when upgrading.
if Sys.iswindows() || (Sys.isapple() && Sys.ARCH === :x86_64)
    get!(ENV, "JULIA_CONDAPKG_ENV", joinpath(AppEnv.USER_DATA, "python_env"))
    try
        mkpath(AppEnv.USER_DATA)
        project = joinpath(AppEnv.USER_DATA, "Project.toml")
        isfile(project) || write(project, "[deps]\n")
        conda = joinpath(AppEnv.USER_DATA, "CondaPkg.toml")
        isfile(conda) || write(conda, """
            [deps.python]
            build = "**cpython**"
            version = ">=3.10,!=3.14.0,!=3.14.1,<4"
            """)
    catch err
        @warn "Could not declare a Python interpreter for CondaPkg." err
    end
end

# --- versions() -------------------------------------------------------------
# `Pkg.status()` is the natural thing to reach for and gives a misleading answer
# here: the bundled packages live in their own stdlib project, so what it reports
# is the user's project, which on a fresh install is empty. Reading the bundle's
# own manifest avoids that, and avoids `Pkg.activate`, which would otherwise
# leave the session pointing at a read-only project.
#
# Defined in `Base` so that it is available unqualified without being shadowed by
# whatever the user later brings into `Main`, matching how `@infiltrate` is
# injected above.
@eval Base begin
    """
        versions()
        versions(pattern; all = false)

    Print the versions of the packages bundled in this distribution.

    By default lists the top-level packages -- the ones the distribution exists to
    ship. `all = true` includes every dependency as well. `pattern` filters by
    name, case-insensitively, and implies `all = true`.

        versions()              # the headline packages
        versions("makie")       # everything matching "makie"
        versions(all = true)    # the lot, several hundred

    Returns the `name => version` pairs it printed.
    """
    function versions(pattern = nothing; all::Bool = false)
        env = joinpath(Sys.STDLIB, "MainEnv")
        manifest = joinpath(env, "Manifest.toml")
        project = joinpath(env, "Project.toml")
        if !isfile(manifest)
            @warn "No bundled manifest found; this does not look like a distribution build." manifest
            return Pair{String,String}[]
        end

        TOML = Base.require(Base.PkgId(
            Base.UUID("fa267f1f-6049-4f14-aa54-33bafae1ed76"), "TOML"))
        deps = Base.invokelatest(TOML.parsefile, manifest)["deps"]

        # A manifest entry is a one-element list holding the package's table. A few
        # entries -- stdlibs shipped with Julia -- carry no version.
        pairs = [String(name) => get(entry[1], "version", "stdlib")
                 for (name, entry) in deps]

        if pattern !== nothing
            needle = lowercase(String(pattern))
            filter!(p -> occursin(needle, lowercase(first(p))), pairs)
        elseif !all
            if isfile(project)
                top = keys(Base.invokelatest(TOML.parsefile, project)["deps"])
                filter!(p -> first(p) in top, pairs)
            end
        end

        sort!(pairs; by = first)
        if isempty(pairs)
            println("No bundled package matches ", repr(pattern), ".")
            return pairs
        end
        width = maximum(length(first(p)) for p in pairs)
        for (name, version) in pairs
            println("  ", rpad(name, width + 2), version)
        end
        return pairs
    end

    export versions
end
