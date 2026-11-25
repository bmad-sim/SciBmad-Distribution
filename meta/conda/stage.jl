# Stage the distribution payload as a plain directory, for conda packaging.
#
# The DMG/MSIX/Snap build paths all wrap the same payload in a platform-specific
# container, and each container imposes its own layout: a `.app` with the tree under
# `Contents/Libraries` on macOS, a snap directory on Linux, an msix directory on
# Windows. A conda package wants none of that -- it wants the payload itself, in the
# same shape on every platform, so that one recipe can install it into a prefix.
#
# `AppBundler.main ... -D compress=false` gets close, but still produces the three
# different container shapes. `JuliaImg.stage` is the step underneath all of them and
# is already platform-parameterised, so calling it directly gives one layout
# everywhere and skips DMG packing and code signing, neither of which a conda
# package needs. (Not needing them is the point of the exercise: no signature means
# nothing for Gatekeeper to reject.)
#
# Usage:
#     julia --project=meta meta/conda/stage.jl --target-arch=aarch64 [--os=macos]
#                                              [--dest=DIR] [--tarball]
#
# Produces `$dest/payload/` and, with `--tarball`, `$dest/<name>-<version>-<os>-<arch>.tar.gz`.

import AppBundler
using AppBundler: JuliaImgBundle, Resources, install, preferences, get_bundle_parameters!
using AppBundler.JuliaImg: stage
using Pkg.BinaryPlatforms: Linux, Windows, MacOS

const SOURCES_DIR = abspath(joinpath(@__DIR__, "..", ".."))

function parse_args(args)
    cfg = Dict{Symbol,Any}(
        :arch => string(Sys.ARCH),
        :os => Sys.isapple() ? "macos" : Sys.iswindows() ? "windows" : "linux",
        :dest => joinpath(SOURCES_DIR, "build", "conda"),
        :tarball => false,
    )
    for a in args
        if startswith(a, "--target-arch=")
            cfg[:arch] = split(a, "=", limit = 2)[2]
        elseif startswith(a, "--os=")
            cfg[:os] = split(a, "=", limit = 2)[2]
        elseif startswith(a, "--dest=")
            cfg[:dest] = abspath(split(a, "=", limit = 2)[2])
        elseif a == "--tarball"
            cfg[:tarball] = true
        else
            error("Unrecognised argument $a")
        end
    end
    cfg[:os] in ("macos", "linux", "windows") || error("Unsupported --os=$(cfg[:os])")
    return cfg
end

"""
    dereference_symlinks!(root) -> (replaced, removed)

Replace every symlink under `root` with a copy of what it points at, and delete the
ones that point at nothing. Returns how many of each.

This exists for Windows. The payload carries around 500 relative symlinks, nearly all
of them Julia package sources doing `docs/src/index.md -> ../../README.md`, and they
have caused two separate failures in the conda build: robocopy could not resolve them
beneath the extended-length (`\\\\?\\`) path rattler-build supplies, and once that was
fixed, following them put robocopy into its default million-retry loop. Symlinks are
second-class on Windows in any case -- creating one needs a privilege an unprivileged
user installing the package may not have -- so the payload is better off without any.

Left alone on macOS and Linux, where symlinks work and save a little space.

Repeats until a pass finds nothing, because replacing a *directory* symlink copies its
target in, and the target may itself contain symlinks that were never scanned.
"""
function dereference_symlinks!(root::String; max_passes::Int = 8)
    total_replaced = total_removed = 0
    for pass in 1:max_passes
        links = String[]
        for (dir, dirs, files) in walkdir(root; follow_symlinks = false)
            for name in Iterators.flatten((dirs, files))
                p = joinpath(dir, name)
                islink(p) && push!(links, p)
            end
        end
        isempty(links) && break
        if pass == max_passes
            @warn "Still finding symlinks after $max_passes passes; giving up" remaining=length(links)
            break
        end
        # Deepest first, so replacing a directory link cannot invalidate a path
        # collected from inside it.
        sort!(links; by = length, rev = true)
        for p in links
            target = try
                realpath(p)
            catch
                nothing
            end
            rm(p; force = true, recursive = false)
            if target === nothing || !ispath(target)
                # A link to nothing is no loss, and copying it is impossible.
                total_removed += 1
            else
                cp(target, p; follow_symlinks = true)
                total_replaced += 1
            end
        end
    end
    return total_replaced, total_removed
end

"""
    cache_dependencies(payload) -> Set{String}

Every source file recorded in the headers of the payload's precompile caches, as an
absolute path inside `payload`. Julia checks these files when it loads a cache, and a
missing one makes the cache stale, so the package would be recompiled on the user's
machine. That would defeat the point of the distribution, so `remove_unless_cached!`
never deletes anything in this set.

The headers hold the paths the files had during staging. They may also be
`@depot`-relative. Both forms are mapped to the payload by what follows `share/julia/`.
"""
function cache_dependencies(payload::String)
    depot = joinpath(payload, "share", "julia")
    deps = Set{String}()
    for (dir, _, files) in walkdir(joinpath(depot, "compiled")), f in files
        endswith(f, ".ji") || continue
        p = joinpath(dir, f)
        header = open(p) do io
            Base.isvalid_cache_header(io) == 0 && return nothing
            Base.parse_cache_header(io, p)
        end
        header === nothing && continue
        for inc in header[2][1]
            name = replace(inc.filename, '\\' => '/')
            rel = if startswith(name, "@depot/")
                name[length("@depot/")+1:end]
            else
                m = findlast("/share/julia/", name)
                m === nothing ? nothing : name[last(m)+1:end]
            end
            rel === nothing || push!(deps, normpath(joinpath(depot, rel)))
        end
    end
    return deps
end

# Longest path, relative to the payload root, that a Windows payload may contain.
#
# Windows refuses paths over 259 characters unless long paths are enabled in the
# registry, which they are not by default (the GitHub runners do have them enabled,
# so CI cannot catch this). conda first unpacks a package into its cache, so the
# payload's paths come on top of
#     C:\Users\<user>\<conda root>\pkgs\scibmad-0.6.0+26.10.14-h9490d1a_0\sb\
# where `sb` is the directory `recipe/build.bat` installs the payload into. Apart from
# the user name and conda root, that is 53 characters.
#
# Before pruning, Qt's headers and CMake files reached 199, and Qt's QML style images
# (`qml/QtQuick/Controls/FluentWinUI3/...`) 173. After pruning, the longest path is a
# DifferentiationInterface extension source, at 160. The precompile caches depend on
# it, so it cannot be pruned. At 160, the install fits for a user name of up to 22
# characters even with conda under `AppData\Local`, and Windows user names have at
# most 20.
#
# The limit is a little above 160, so the current payload passes and a new long path
# fails the build. At 165 the install still fits for a user name of up to 17
# characters under `AppData\Local\miniforge3`, or 31 under `miniforge3`.
const WINDOWS_MAX_RELPATH = 165

# Directories at the top of a package's source tree that nothing loads at run time.
const DEV_ONLY_PACKAGE_DIRS = ("test", "docs", "benchmark", "benchmarks")

# Directories inside an artifact that hold files for building against it or for reading
# about it, not files it loads: C/C++ headers, CMake and pkg-config files, and
# documentation. Artifacts are only ever loaded as shared libraries or run as programs.
const DEV_ONLY_ARTIFACT_DIRS = (
    "include",
    joinpath("lib", "cmake"),
    joinpath("lib", "pkgconfig"),
    joinpath("share", "doc"),
    joinpath("share", "man"),
    joinpath("share", "info"),
    joinpath("share", "gtk-doc"),
)

# Directories of package sources that do not belong in the payload on any platform.
#
# NonlinearNormalForm's `fpp-ptc-sandbox/` holds FPP/PTC Fortran experiments, and the
# released package commits their CMake build output with them: `CMakeCache.txt`,
# `CMakeFiles/` and compiled `.o` files, about 600 files and 16 MB. None of it is
# Julia, and nothing in the package loads it. Its paths also reach 188 characters,
# more than a Windows install has room for. Staging builds none of this; it arrives
# with the package source.
const UNUSED_PACKAGE_DIRS = ("NonlinearNormalForm" => "fpp-ptc-sandbox",)

# Directories at the top of an artifact that do not belong in the payload on any
# platform.
#
# `qml/` holds Qt's QML modules: `qmldir` files, `.qml` sources, style images and QML
# plugins. They are read only by a running QML engine, and nothing in the distribution
# starts one. Qt reaches the payload only through GR, whose viewer `gksqt` is a
# QtWidgets program; it links QtWidgets, QtNetwork, QtGui and QtCore and nothing else.
# Qt6Declarative, which provides QML, comes in only as a dependency of Qt6Wayland_jll.
# That package exists only on Linux and FreeBSD, and needs the Qt Quick libraries,
# which are in `lib/` and are kept. Removing `qml/` saves about 1,600 files and 24 MB,
# and removes the longest paths that remain on Windows (173 characters) once the
# development files are gone.
const UNUSED_ARTIFACT_DIRS = ("qml",)

"""
    remove_unless_cached!(candidates, deps) -> (removed, kept)

Delete each existing file or directory in `candidates`, except a file in `deps` (see
`cache_dependencies`) or a directory that holds one. Deleting one of those would make
Julia recompile the package that depends on it, so it is returned in `kept` instead.
"""
function remove_unless_cached!(candidates, deps::Set{String})
    removed, kept = String[], String[]
    for c in unique(candidates)
        ispath(c) || continue
        needed = if isdir(c)
            prefix = normpath(c) * Base.Filesystem.path_separator
            any(startswith(prefix), deps)
        else
            normpath(c) in deps
        end
        if needed
            push!(kept, c)
        else
            rm(c; recursive = true, force = true)
            push!(removed, c)
        end
    end
    return removed, kept
end

package_dirs(depot) =
    [pkg for stdlib in filter(isdir, readdir(joinpath(depot, "stdlib"); join = true))
         for pkg in filter(isdir, readdir(stdlib; join = true))]

"""
    prune_unused!(payload) -> (removed_dirs, kept_dirs)

Delete the directories named in `UNUSED_PACKAGE_DIRS` and `UNUSED_ARTIFACT_DIRS`. Runs
on every platform.
"""
function prune_unused!(payload::String)
    depot = joinpath(payload, "share", "julia")
    candidates = [joinpath(pkg, d) for pkg in package_dirs(depot)
                  for (name, d) in UNUSED_PACKAGE_DIRS if basename(pkg) == name]
    artifacts = joinpath(depot, "artifacts")
    if isdir(artifacts)
        for a in readdir(artifacts; join = true), d in UNUSED_ARTIFACT_DIRS
            push!(candidates, joinpath(a, d))
        end
    end
    return remove_unless_cached!(candidates, cache_dependencies(payload))
end

"""
    checkbounds_cache_files(depot) -> Vector{String}

The files of every precompile cache built for `--check-bounds=yes` whose package also
has a cache built without it.

Julia's binary distribution ships its stdlibs precompiled twice, with and without
`--check-bounds=yes`, about 54 packages and 160 MB (28 MB compressed). A session uses
only the variant whose bounds-checking mode matches its own. Only `--check-bounds=yes`
picks the first, and that is mostly `Pkg.test`. After pruning, such a session compiles
those stdlibs into the user depot once.

A cache is a `.ji` file plus, with package images, a shared library and on macOS its
`.dSYM`, all named `<stem>.<ext>`. All of them are returned.
"""
function checkbounds_cache_files(depot::String)
    found = String[]
    compiled = joinpath(depot, "compiled")
    isdir(compiled) || return found
    for (dir, _, files) in walkdir(compiled)
        jis = filter(endswith(".ji"), files)
        length(jis) > 1 || continue
        flags = Dict(f => open(joinpath(dir, f)) do io
                         Base.isvalid_cache_header(io) == 0 && return nothing
                         Base.CacheFlags(read(io, UInt8))
                     end for f in jis)
        any(fl -> fl !== nothing && fl.check_bounds == 0, values(flags)) || continue
        for (f, fl) in flags
            (fl !== nothing && fl.check_bounds == 1) || continue
            stem = f[1:end-length(".ji")]
            for g in readdir(dir)
                (g == f || startswith(g, stem * ".")) && push!(found, joinpath(dir, g))
            end
        end
    end
    return found
end

"""
    prune_dev_files!(payload) -> (removed, kept)

Delete what the payload carries but nothing uses at run time. Runs on every platform.
On Windows it runs after symlinks are dereferenced, which can copy new files in.

- In artifacts (`share/julia/artifacts/*/`): the directories in `DEV_ONLY_ARTIFACT_DIRS`,
  the CMake object-library directories (`objects-*`) that Qt leaves in its module
  directories, and static libraries (`*.a`, which includes Windows import libraries
  `*.dll.a`). Qt's private headers and CMake files are also the longest paths in the
  payload, which matters on Windows.
- In package sources (`share/julia/stdlib/v1.13/*/`): the directories named in
  `DEV_ONLY_PACKAGE_DIRS`.
- `share/julia/clones/`: Pkg's git clones of the packages tracked by URL (SciBmad).
  Pkg reads them only to add or update those packages, which is never done to the
  bundled environment. About 75 MB, already compressed, so it is the same in the package.
- `*.dSYM` bundles (macOS): debug symbols for Julia's libraries and for every package
  image, read only by a debugger. About 525 MB, 75 MB compressed.
- Precompile caches for `--check-bounds=yes` (`checkbounds_cache_files`).

As in `remove_unless_cached!`, nothing a precompile cache depends on is deleted.
"""
function prune_dev_files!(payload::String)
    depot = joinpath(payload, "share", "julia")
    candidates = String[]

    artifacts = joinpath(depot, "artifacts")
    if isdir(artifacts)
        for a in readdir(artifacts; join = true)
            isdir(a) || continue
            append!(candidates, joinpath(a, d) for d in DEV_ONLY_ARTIFACT_DIRS)
            for (dir, dirs, files) in walkdir(a)
                for d in dirs
                    startswith(d, "objects-") && push!(candidates, joinpath(dir, d))
                end
                for f in files
                    endswith(f, ".a") && push!(candidates, joinpath(dir, f))
                end
            end
        end
    end
    libdir = joinpath(payload, "lib")
    if isdir(libdir)
        for (dir, _, files) in walkdir(libdir), f in files
            endswith(f, ".a") && push!(candidates, joinpath(dir, f))
        end
    end

    for pkg in package_dirs(depot), d in DEV_ONLY_PACKAGE_DIRS
        push!(candidates, joinpath(pkg, d))
    end

    push!(candidates, joinpath(depot, "clones"))

    for (dir, dirs, _) in walkdir(payload)
        for d in dirs
            endswith(d, ".dSYM") && push!(candidates, joinpath(dir, d))
        end
    end

    append!(candidates, checkbounds_cache_files(depot))

    # A `.dSYM` can be found both on its own and as part of a check-bounds cache, and a
    # directory can be removed before a candidate inside it; `remove_unless_cached!`
    # skips paths that no longer exist.
    return remove_unless_cached!(candidates, cache_dependencies(payload))
end

"""
    long_paths(root, limit) -> Vector{String}

Every path under `root` whose length relative to `root` is over `limit`, longest first.
"""
function long_paths(root::String, limit::Int)
    found = String[]
    n = length(root) + 1
    for (dir, dirs, files) in walkdir(root), name in Iterators.flatten((dirs, files))
        rel = joinpath(dir, name)[n+1:end]
        length(rel) > limit && push!(found, rel)
    end
    return sort!(found; by = length, rev = true)
end

platform_for(os, arch) =
    os == "macos"   ? MacOS(Symbol(arch)) :
    os == "linux"   ? Linux(Symbol(arch)) :
                      Windows(Symbol(arch))

function main(args)
    cfg = parse_args(args)
    arch, os, dest = cfg[:arch], cfg[:os], cfg[:dest]

    # Both of these are done here rather than in the workflow, because forgetting
    # either produces a failure an hour into a build rather than at the start, and
    # the DMG workflow has already had to learn both of them the hard way.
    #
    # `CI` decides how AppBundler compiles the bundled packages (`JuliaImg.jl:93`):
    # unset, it calls `Pkg.precompile`; set -- as it always is on a runner -- it
    # `import`s every package instead, which runs each package's `__init__`.
    # PythonCall's `__init__` resolves a Conda environment, which inside the staging
    # tree ends as `InitError: Python executable ... does not exist`.
    delete!(ENV, "CI")
    # For the two platforms that get no bundled interpreter -- Windows, which
    # Python_jll does not build for, and macOS x86_64, whose build is broken -- the
    # PythonCall patch has nothing to point at, so PythonCall would resolve an empty
    # Conda environment in the staging tree and fail the same way. `Null` makes it
    # use the `python` on PATH, which only has to survive `__init__` while packages
    # compile; nothing about it enters the payload. On the other platforms the patch
    # sets this same value itself, so setting it here is harmless.
    get!(ENV, "JULIA_CONDAPKG_BACKEND", "Null")

    # Same preference resolution `AppBundler.main_build` performs, so that a payload
    # staged here is configured identically to the one inside a released DMG.
    project_preferences = Resources.get_project_preferences(SOURCES_DIR)
    prefs = merge(project_preferences["AppBundler"], Dict{String,Any}())

    parameters = get_bundle_parameters!(Dict{String,Any}(),
                                        joinpath(SOURCES_DIR, "Project.toml");
                                        preferences = prefs)
    app_name = parameters["APP_NAME"]
    bundle_identifier = parameters["BUNDLE_IDENTIFIER"]
    version = parameters["APP_VERSION"]

    # `juliaimg_selective_assets` is off for this project, so sources are kept whole;
    # mirrored from `main_build` rather than assumed, in case that preference changes.
    if get(prefs, "juliaimg_selective_assets", false)
        remove_sources = true
        asset_spec = Resources.extract_asset_spec(SOURCES_DIR; project_preferences)
    else
        remove_sources = false
        asset_spec = Dict{Symbol,Vector{String}}()
    end

    product = JuliaImgBundle(SOURCES_DIR;
                             precompile = prefs["juliaimg_precompile"],
                             incremental = prefs["juliaimg_incremental"],
                             sysimg_packages = prefs["juliaimg_sysimg"],
                             remove_sources,
                             asset_spec)

    payload = joinpath(dest, "payload")
    ispath(payload) && rm(payload; recursive = true, force = true)
    mkpath(payload)

    # RUNTIME_MODE is deliberately MIN rather than the SANDBOX the DMG uses. SANDBOX
    # asks AppEnv to find the per-user depot through the container it assumes it is
    # running in, and outside that container two of the three platforms fall back to a
    # temporary directory that is wiped between runs -- `set_depot_path_snap!` when
    # `SNAP` is unset, and `set_depot_path_msix!` when the MSIX package cannot be
    # found. A conda install is in no container at all, so those are exactly the
    # branches it would take, and anything the user added with `Pkg.add` would not
    # survive to the next session.
    #
    # MIN reads `USER_DATA` from the environment on every platform and puts the user
    # depot under it. The `bin/` shim in the conda package sets that variable to a
    # persistent per-user path, which makes the behaviour identical everywhere and
    # keeps it out of the install prefix -- prefixes get deleted and recreated, and
    # may be read-only or shared between users.
    stage(product, payload;
          platform = platform_for(os, arch),
          runtime_mode = "MIN",
          app_name,
          bundle_identifier)

    install(product.startup_file, joinpath(payload, "etc/julia/startup.jl");
            parameters, force = true)

    removed_dirs, kept_dirs = prune_unused!(payload)
    @info "Removed unused directories" removed_dirs
    isempty(kept_dirs) || @warn "Kept because a precompile cache depends on them" kept_dirs

    if os == "windows"
        @info "Dereferencing symlinks for Windows"
        replaced, removed = dereference_symlinks!(payload)
        @info "Symlinks resolved" replaced removed
    end

    # On Windows after dereferencing, which can copy a directory's contents in and so
    # make new long paths.
    @info "Pruning development files from the payload"
    pruned, kept = prune_dev_files!(payload)
    @info "Pruned" paths=length(pruned)
    isempty(kept) || @warn "Kept because a precompile cache depends on them" kept

    if os == "windows"
        too_long = long_paths(payload, WINDOWS_MAX_RELPATH)
        if !isempty(too_long)
            error("$(length(too_long)) payload paths are longer than " *
                  "$WINDOWS_MAX_RELPATH characters and will not install on Windows " *
                  "without long paths enabled. Longest:\n  " *
                  join(first(too_long, 20), "\n  "))
        end
    end

    @info "Staged payload" payload version os arch

    if cfg[:tarball]
        name = "$(app_name)-$(version)-$(os)-$(arch).tar.gz"
        tarball = joinpath(dest, name)
        rm(tarball; force = true)
        @info "Creating tarball" tarball
        # `-C payload .` so the archive has no leading directory: the conda build
        # script copies the contents straight into the prefix.
        run(`tar -czf $tarball -C $payload .`)
        @info "Tarball written" tarball size=Base.format_bytes(filesize(tarball))
    end

    return 0
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main(ARGS)
