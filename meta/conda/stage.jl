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
