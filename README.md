# SciBmad-Distribution

A Julia **distribution** that ships [SciBmad](https://github.com/bmad-sim/SciBmad) — the Julia
toolkit for charged particle beam dynamics. Besides SciBmad, this distribution bundles a number of additional
packages and their dependencies.
A list of these additional packages is in the `Project.toml` file.

Install this distribution (see below), launch Julia, and `using SciBmad` returns
immediately: no package installation, no first-use compilation wait.
Additional packages can still be installed with Pkg without triggering recompilation of the bundled ones.

The distribution is built with [AppBundler.jl](https://github.com/PeaceFounder/AppBundler.jl)
and follows the [Jumbo](https://github.com/JanisErdmanis/Jumbo) template. All packages in the distribution, 
including dependencies, is bundled into the stdlib path of the shipped Julia so that they are never accidentally
recompiled.

## What is included

- **SciBmad core**: `SciBmad`, `Beamlines`, `BeamTracking`, `NonlinearNormalForm`, `GTPSA`,
  `TPSAInterface`, `AtomicAndPhysicalConstants`, `FundamentalFrequencies`, `BatchSolve`,
  `KernelAbstractions`
- **Differentiation and arrays**: `ADTypes`, `DifferentiationInterface`, `ForwardDiff`,
  `ReverseDiff`, `FiniteDiff`, `StaticArrays`, `TypedTables`, `PreallocationTools`
- **Optimization and solvers**: `Optim`, `NLSolversBase`, `OptimizationOptimJL`,
  `OptimizationLBFGSB`, `NonlinearSolve`, `Metaheuristics`, `Sobol`
- **Statistics**: `Distributions`, `Turing`
- **Plotting**: `Makie` with the `CairoMakie`, `GLMakie` and `WGLMakie` backends, plus `Plots`
  and `LaTeXStrings`
- **Data and utilities**: `DataFrames`, `Graphs`, `JSON`, `SpecialFunctions`,
  `ReferenceFrameRotations`
- **Interactive tooling**: `Revise`, `Infiltrator` (both loaded automatically by
  `meta/startup.jl` in interactive sessions)
- **Python interoperability**: `PythonCall`, together with the `Python_jll` interpreter it
  runs against

## Installation

Download the appropriate pre-built distribution (MSIX, Snap, or DMG) from the **Assets**
section on the [releases page](https://github.com/bmad-sim/SciBmad-Distribution/releases)
(you may need to expand the Assets dropdown for prerelease versions), then follow the
instructions for your platform:

- **MSIX (Windows)**: If self-signed, open the MSIX bundle properties and add the certificate
  to the trusted certificate authorities first (see
  https://www.advancedinstaller.com/install-test-certificate-from-msix.html). Then
  double-click the installer and install the app.
- **Snap (Linux)**: `snap install --classic --dangerous SciBmadDistribution.snap`
- **DMG (macOS)**: If self-signed, click on the app first, then go to
  `Settings -> Privacy & Security` and whitelist the launch request. Then drag and drop the
  application into the `Applications` folder. Launch the application and go again to
  `Settings -> Privacy & Security` to whitelist it.

These extra steps are avoidable with an investment in Windows and macOS code signing
certificates. For Snap, the app can be submitted to the Snap Store so it can be installed
through a GUI.

# For Maintainers:

## Julia versions

Building works on Julia 1.11 and 1.12 alike. The host Julia only runs AppBundler itself:
the bundled Julia, the packages copied into it, and their precompilation all come from
`Manifest.toml`, so a build driven by 1.12 still produces a bundle containing Julia 1.11.7.

Do **not** run `Pkg.resolve()` or `Pkg.update()` on this repository under a Julia newer than
1.11. Doing so rewrites `julia_version` in `Manifest.toml` and would silently change the Julia
shipped to users on the next release. This is why the release workflow pins `setup-julia` to
`1.11`; use 1.11 for any package-set update.

Using the repository as a development environment under 1.12 works but is slightly degraded:
Pkg warns that the manifest was resolved by a different Julia version (and, because Pkg 1.12
hashes `Project.toml` differently, wrongly reports the manifest as stale), and manifest entries
for packages that are standard libraries in 1.11 but not in 1.12 — notably `MbedTLS_jll` — have
no download recorded, so `MbedTLS`, `HTTP` and `FileIO`'s HTTP extension fail to precompile.
The bundle is unaffected, since it ships 1.11.

## Building

- Install Julia 1.11 or later.

- Edit `Project.toml`: set the `SciBmad` compat entry to the version to build the distribution
  around. Also update the `version` string to the current date. The format is `"YY.M.D"` where
  `M` is the month and `D` is the day without any leading zeros. Example: Use `"26.8.3"` 
  instead of `"26.08.03"`.

- Re-resolve the package set so that `Manifest.toml` matches the new compat entry. Use Julia
  1.11 for this, for the reason given under [Julia versions](#julia-versions):

  ```bash
  julia --project=. -e 'using Pkg; Pkg.update()'
  ```

- Install the build dependencies:

  ```bash
  julia --project=meta -e 'using Pkg; Pkg.instantiate()'
  ```

- Perform the build:

  ```bash
  julia --project=meta -e 'import AppBundler; AppBundler.main(ARGS)' build . --build-dir=build --selfsign
  ```

  Everything after the `-e` expression is passed through to AppBundler's command line. On Julia
  1.12 or later the shorter `julia --project=meta -m AppBundler build . --build-dir=build
  --selfsign` form works as well, but `-m` does not exist in 1.11, so the invocation above is
  the portable one. Pass `AppBundler.main(["--help"])` to see all build options. This creates
  build artifacts in the `build` directory; by default the bundle targets the host platform.

- Push the updated `Project.toml` and `Manifest.toml` to the GitHub repo main branch via a
  Pull Request.

- Under the `Actions` menu, press `Build Release Assets` and then `Run workflow`. To have the
  bundles attached to a release, put the tag of an existing release in the optional
  `Release tag to upload to` field; left empty, the run only leaves the bundles as workflow
  artifacts, which are deleted after a day. The same workflow also runs automatically whenever
  a release is created.

Note: `import AppBundler` is used, not `using AppBundler`. AppBundler exports `main` and marks
it with `@main`, so `using` brings `main` into `Main` and Julia's entry point invokes it a
second time with the same arguments once the `-e` expression returns — building the whole
bundle twice.

Build with `CI` unset in the environment, and make sure any CI workflow clears it — the
release workflow does so from inside Julia, with `julia -e 'delete!(ENV, "CI"); import
AppBundler; ...'`, which works the same on every runner shell. AppBundler chooses how to
compile packages into the bundle based on that variable (`JuliaImg.jl:93`): without it, it
calls `Pkg.precompile`; with it, it loads every package with `import` instead. `import` runs
every package's `__init__`, which for a bundle this size means running a great deal of code
that has no business running on a build machine — PythonCall's `__init__`, for one, starts a
Python interpreter. `Pkg.precompile` runs an `__init__` only when compiling something requires
loading the package, which is far less often.
Set `JULIA_NUM_PRECOMPILE_TASKS` to bound the parallelism if the builder is short on memory.

Cross-building the macOS x86_64 bundle from an Apple Silicon machine needs an x86_64 `python`
on `PATH` and `JULIA_CONDAPKG_BACKEND=Null` in the environment. That target is the one that
cannot use its own bundled interpreter while compiling, so PythonCall falls back to the
`python` it can find, and it loads that interpreter's libpython into the (Rosetta-translated,
x86_64) Julia process — an arm64 Python will not load there. The release workflow installs one
with `actions/setup-python`. Nothing from it enters the bundle.

## Updating the package set

Edit `Project.toml`, re-resolve, and commit the updated `Manifest.toml`:

```bash
julia --project=. -e 'using Pkg; Pkg.update()'
```

Use Julia 1.11 for this, for the reason given under [Julia versions](#julia-versions).

## Patches

Files under `meta/patches/<Package>/…` are copied over the corresponding files of the bundled
packages during the build. Three patches are currently applied:

- `meta/patches/GLMakie/src/precompiles.jl` — GLMakie's `@setup_workload` block opens an
  OpenGL screen, which is not available while packages are precompiled into the bundle. The
  patched copy comments that block out and keeps the static `precompile()` statements. It was
  generated from GLMakie v0.13.13 and must be regenerated when GLMakie is upgraded: copy
  `src/precompiles.jl` from the new version and comment out the `macro compile` definition
  and the `let @setup_workload … end` block.

- `meta/patches/PythonCall/src/Core/juliacall.jl` — PythonCall locates its bundled `juliacall`
  Python package through `ROOT_DIR`, which is `dirname(dirname(@__DIR__))` and is therefore
  frozen at precompile time. AppBundler precompiles into a staging directory and the bundle is
  installed somewhere else, so the recorded path no longer exists and `using PythonCall` fails
  with `ModuleNotFoundError: No module named 'juliacall'`. The patched copy locates the package
  through the load path instead, which follows the bundle wherever it is installed. It was
  generated from PythonCall v0.9.35 and must be regenerated when PythonCall is upgraded: copy
  `src/Core/juliacall.jl` from the new version and replace the two uses of `ROOT_DIR` inside
  `init_juliacall` with the load-path lookup.

- `meta/patches/PythonCall/src/C/C.jl` — PythonCall asks CondaPkg to download and resolve a
  Python environment when it is first loaded. The bundle ships its own interpreter in
  `Python_jll`, and CondaPkg cannot work inside a read-only install anyway, so the patched
  copy points PythonCall at the bundled interpreter from `PythonCall.C.__init__`. It runs
  there, rather than from `meta/startup.jl`, because the build needs the same configuration:
  compiling a package that has a PythonCall extension loads PythonCall in a Pkg worker
  process, which never reads a startup file. The JLL is loaded on every such entry even when
  the environment variables are already set — Pkg's workers inherit environment variables but
  not loaded libraries, and Python's `ctypes` (imported by `juliacall` during initialisation)
  only finds `libffi` because loading the JLL brought it into the process.

  The same patch skips the bundled interpreter on macOS x86_64, where Python_jll's build is
  unusable. It is compiled with a 10.10 deployment target, so clang guards the 10.12-only
  `getentropy` call in `pyurandom` with `__builtin_available`, which compiles to a call to
  `___isPlatformVersionAtLeast`. That symbol is left as a flat-namespace dynamic lookup and
  nothing in the process resolves it, so it binds to NULL and `Py_InitializeFromConfig` jumps
  to address zero. `python3 -V` survives because it returns before reaching that code;
  anything else dies with `SIGSEGV`. The aarch64 build targets macOS 11, where `getentropy`
  needs no guard, which is why only this one platform is affected. This is an upstream bug in
  `Python_jll 3.11.12+0`, and the skip can be dropped once a fixed build exists.

  On those two platforms the same patch also has to find libpython. PythonCall locates it by
  running `src/C/find_libpython.py`, at a path `@__DIR__` baked in at precompile time — inside
  the build machine's staging directory, which does not exist on the installed machine. This
  is the same relocation problem the `juliacall.jl` patch solves for `ROOT_DIR`. The patch
  runs the script from where PythonCall actually is and passes the answer in
  `JULIA_PYTHONCALL_LIB`.

  It was generated from PythonCall v0.9.35 and must be regenerated when PythonCall is
  upgraded: copy `src/C/C.jl` from the new version and re-apply the block after the
  `include`s along with the two calls in `__init__`.

## Notes

`PythonCall` is bundled with a Python interpreter, so `using PythonCall` returns in about a
second and needs neither a download nor a network connection. A patch to PythonCall itself
(see "Patches" above) points it at the `Python_jll` interpreter inside the bundle and switches
CondaPkg's environment management off; left to itself, PythonCall would try to resolve a Conda
environment on first use, which would both impose the wait this distribution exists to avoid
and fail outright, since it would have to write inside the read-only install directory.
Packages can still be added to that interpreter from within the distribution with `CondaPkg`
once it is pointed at a writable environment.

Two platforms get no bundled interpreter. Python_jll has no Windows build at all, and its
macOS x86_64 build is broken — it segfaults during interpreter startup on every Intel Mac,
not just under Rosetta (the patch documents the cause). There PythonCall falls back to
CondaPkg, which `meta/startup.jl` points at a writable directory beside the user's data and
tells which interpreter to install; the patch to PythonCall then finds the resulting library.
The first `using PythonCall` downloads a Python environment once and works normally
thereafter, though every later load still pays for a CondaPkg resolve check rather than the
bundled path's second or so. This is the slow path the distribution exists to avoid, and it is
taken only where the fast one is unavailable.

Three Makie backends are bundled. `CairoMakie` is the default used by the tutorial notebooks:
it renders static PNG/SVG/PDF output and needs no graphics hardware. `GLMakie` adds
interactive, zoomable, 3D-capable windows, but requires a working OpenGL 3.3 context, so
`using GLMakie` will fail on headless machines, over an SSH session without display
forwarding, and in some containers and virtual machines — use `CairoMakie` there. `WGLMakie`
renders into a browser and is the backend to use from a notebook served over the network. When
several are loaded, whichever was activated last (`CairoMakie.activate!()` and friends)
receives the plots.

`Manifest.toml` records the exact resolved versions. Both it and `meta/Manifest.toml` were
resolved with Julia 1.11, the minimum version this distribution supports, and AppBundler takes
the Julia version to ship inside the bundle from their `julia_version` field.
