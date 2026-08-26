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
- **Interactive tooling**: `Infiltrator` (loaded automatically by `meta/startup.jl` in
  interactive sessions)
- **Notebooks**: `IJulia`, so the bundled Julia can be used as a Jupyter kernel (see
  "Using the Distribution from Jupyter" below)
- **Python interoperability**: `PythonCall`, together with the `Python_jll` interpreter it
  runs against

## Installation

Currently, the Distribution only works with Julia version 1.12

Download the appropriate pre-built distribution (MSIX, Snap, or DMG) from the **Assets**
section on the [releases page](https://github.com/bmad-sim/SciBmad-Distribution/releases)
(you may need to expand the Assets dropdown for prerelease versions), then follow the
instructions for your platform:

- **MSIX (Windows)**: The released bundles are signed with a self-signed certificate, so
  Windows will not trust them out of the box. Open the MSIX bundle properties and add its
  certificate to the trusted certificate authorities first (see
  https://www.advancedinstaller.com/install-test-certificate-from-msix.html). Then
  double-click the installer and install the app.
- **Snap (Linux)**: `snap install --classic --dangerous SciBmadDistribution.snap`
- **DMG (macOS)**: The released bundles are signed with a self-signed certificate, so macOS
  does not trust them out of the box. In addition, macOS attaches a *quarantine* flag to
  anything copied out of a downloaded disk image, and Gatekeeper refuses to launch a
  quarantined app that it cannot verify. To get around the security, 
  install from the Terminal, substituting the appropriate directory and name of the 
  dmg file you downloaded in the first line (the other lines do not need to be modified):
  ```bash
  hdiutil attach ~/Downloads/scibmaddistribution-26.8.23-aarch64.dmg
  ditto "/Volumes/SciBmadDistribution Installer/SciBmadDistribution.app" /Applications/SciBmadDistribution.app
  hdiutil detach "/Volumes/SciBmadDistribution Installer"
  sudo xattr -dr com.apple.quarantine /Applications/SciBmadDistribution.app
  sudo chmod -R a-w /Applications/SciBmadDistribution.app
  ```
  This may take a minute or two. Note: The `sudo` commands will ask for a password.

## Using the Distribution

- Install Julia 1.12 if needed.

- Run the `SciBmadDistribution` app. This should open a Julia window.

- The command `using SciBmad` will load the Distribution.

## Using the Distribution from Jupyter

`IJulia` is bundled, so the distribution can serve as a Jupyter kernel. Jupyter itself is not
bundled — use whichever installation you already have. Register a kernel once, from inside the
distribution:

```julia
using IJulia
IJulia.installkernel("SciBmad")
```

That writes a kernel specification into your own Jupyter data directory (never inside the
read-only app), pointing at the bundled Julia. `SciBmad` then appears in Jupyter's kernel list
and notebooks using it get the whole distribution with no precompilation wait.

Two things to know. Register the kernel from the app itself rather than from another Julia:
a kernel is only useful if its `argv` names the bundled binary, and `installkernel` records
whichever Julia is running it. And a kernel specification is just a file keyed by name, so
registering `SciBmad` from two different Julia installations means the second silently
replaces the first — give them different names if you want both.

`IJulia.notebook()` and `IJulia.jupyterlab()` also work, provided `jupyter` is on `PATH`; the
patch below makes IJulia look it up at run time. They cannot fall back to installing Jupyter
through Conda the way a normal IJulia install does, because that would have to write inside
the read-only bundle.

# For Maintainers:

## Building

- If desired, modify the set of packages to be bundled by editing `Project.toml`.

- Edit `Project.toml`: set the `SciBmad` compat entry to the version to build the distribution
  around. Also update the `version` string to the current date. The format is `"YY.M.D"` where
  `M` is the month and `D` is the day without any leading zeros. Example: Use `"26.8.3"` 
  instead of `"26.08.03"`. 

  If changing the Julia version, this needs to be changed in three files: `Project.toml`, 
  `meta/Project.toml`, and `.github/workflows/Release.yml`

- Re-resolve the package set so that `Manifest.toml` matches the new compat entry;
  ```bash
  julia --project=. -e 'using Pkg; Pkg.update()'
  ```

- Install the build dependencies. This also re-resolves `meta/Manifest.toml` against the Julia
  version set in `meta/Project.toml`, so it is required even if you skip the local build below:
  ```bash
  julia --project=meta -e 'using Pkg; Pkg.instantiate()'
  ```

- Optionally, verify the build locally. This is not needed to produce a release but can save time
  when debugging. The output goes
  to the gitignored `build` directory, and the release workflow rebuilds everything from a fresh
  checkout. It may be worth doing to catch a broken build in one local run rather than after
  a five-platform CI matrix, but it targets the host platform only, so it cannot reproduce the
  platform-specific failures the workflow guards against:
  ```bash
  julia --project=meta -m AppBundler build . --build-dir=build --selfsign
  ```

- Push the updated `Project.toml`, `Manifest.toml`, `meta/Project.toml` and `meta/Manifest.toml`
  to the GitHub repo main branch via a Pull Request. `meta/Manifest.toml` 
  records the Julia version the build dependencies were resolved against, and the
  release workflow installs exactly the versions it pins.

- In GitHub under the `Actions` menu, press `Build Release Assets` and then `Run workflow`. 
  To have the bundles attached to a release, put the tag of an existing release in the optional
  `Release tag to upload to` field; left empty, the run only leaves the bundles as workflow
  artifacts, which are deleted after a day. The same workflow also runs automatically whenever
  a release is created.

## Patches

Files under `meta/patches/<Package>/…` are copied over the corresponding files of the bundled
packages during the build. Five patches are currently applied:

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

- `meta/patches/IJulia/deps/deps.jl` — IJulia refuses to load unless `deps/deps.jl` exists:
  `src/IJulia.jl` aborts with `IJulia not properly installed. Please run Pkg.build("IJulia")`.
  That file is written by `Pkg.build("IJulia")`, and AppBundler copies pristine package trees
  into the bundle without ever running `deps/build.jl`, so bundling IJulia used to fail every
  build — which is why it was dropped from the distribution in August 2026.

  Unlike the patches above, this one supplies the generated file rather than a forked copy of
  a source file, so it does not have to be regenerated when IJulia is upgraded; it only has to
  keep defining the two names `deps.jl` is contracted to define. `JUPYTER` is set to the bare
  string `"jupyter"`, which `find_jupyter_subcommand` already treats as "look it up on `PATH`".
  That is deliberate: the stock `deps/build.jl` records an absolute path to the Jupyter it
  found on the build machine, which is meaningless on the installed machine, and the bare
  string is what turns the lookup into a run-time one. `IJULIA_DEBUG` is `false`, which is what
  a stock build writes when the variable is unset, and as upstream it is frozen at build time.

- `meta/patches/Conda/deps/deps.jl` — `Conda` arrives as a dependency of IJulia and fails the
  same way, with `Conda is not properly configured. Run Pkg.build("Conda")`. It is precompiled
  into the bundle whether or not anything calls it, so it needs the same treatment. The patch
  supplies `deps/build.jl`'s own default values, computed rather than hardcoded so the build
  machine's depot path does not appear in the file.

  The `mkpath` in it is load bearing: `src/Conda.jl` evaluates `const PREFIX = prefix(ROOTENV)`
  at precompile time and `prefix` throws unless that directory already exists, which
  `Pkg.build("Conda")` would otherwise have created.

  One limitation is worth recording. `Conda.ROOTENV` and everything derived from it stay
  `const`, so they are still frozen at precompile time and inside the installed bundle they
  point at the build's staging depot, which no longer exists. Nothing in the distribution
  calls Conda — the only path that reaches it is `IJulia.notebook()` reading
  `Conda.SCRIPTDIR` as a fallback after `Sys.which("jupyter")` has already failed — so this is
  latent rather than a fault. Making it correct would mean converting roughly ten `const`s in
  `Conda.jl` into run-time globals, which is a fork of the file rather than a patch to it.

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

For the macOS install, the closing `chmod` makes the installed bundle read-only. 
The distribution ships its Julia
package cache inside the app itself; if Julia writes there while running, it invalidates the
app's code signature and macOS then refuses to launch it.

For the macOS install, 
if you prefer the Finder, the order matters: click the app on the mounted disk image
*first* and approve it under `Settings -> Privacy & Security`, and only then drag it into
`Applications`. Dragging before approving is what fails. Then apply the `chmod` command
above to prevent modification of the app. 
If the app shows a white "no entry" circle and will not start, 
something has written a file inside the app bundle after installation, which invalidates its
code signature. macOS then refuses to launch it and reports nothing at all: no error dialog,
no crash report, no log entry. Confirm with:

```bash
codesign --verify --strict /Applications/SciBmadDistribution.app
```

A reply of `a sealed resource is missing or invalid` identifies this problem, and the
accompanying `file added:` line names the file responsible. Removing that file restores the
signature and the app starts normally:

```bash
sudo rm "/Applications/SciBmadDistribution.app/<path from the file added: line>"
```

Reinstalling also works, but the problem will recur unless the `chmod -R a-w` step from the
installation instructions is applied.

