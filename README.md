# SciBmad-Distribution

A Julia **distribution** that ships [SciBmad](https://github.com/bmad-sim/SciBmad) — the Julia
toolkit for charged particle beam dynamics. Besides SciBmad, this distribution bundles a number of additional
packages and their dependencies.
A list of these additional packages is in the `Project.toml` file.

Install this distribution (see below), launch the Distribution executable, and `using SciBmad` returns
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

There are two ways to install: from conda, or from a app installer. Conda is the
easier one and is recommended. The app installer route is documented at the
very end of this README file.

Note that the distribution ships its own Julia, so Julia does not need to be installed
separately. The bundled Julia is version 1.12.

### Conda Install (recommended)

To install and run SciBmad in a julia session do:
```bash
conda install -c bmad-sim scibmad  # Only need to do once.
scibmad                            # Starts julia
using scibmad                      # Brings scibmad into scope
```
The install may take a minute or two. The `using scibmad` may also take a minute the first time.

This works on Linux (x86-64 and aarch64), macOS (Intel and Apple silicon), and Windows
(x86-64). Mamba, micromamba and pixi work as well as conda.

### Conda Maintenance 

Useful Conda commands:
```bash
conda list | grep scibmad        # Installed version, e.g. 0.5.2+26.09.01 -- see "Version numbers" below.
conda search -c bmad-sim scibmad # List all versions available on the channel.
conda update -c bmad-sim scibmad # Update to the latest version.
conda uninstall scibmad          # Uninstall. No channel needed: it only removes what is installed.
```

### Version numbers

A conda version looks like `0.5.2+26.09.01`. The first part is the version of `SciBmad`
itself; the part after the `+` is the date the distribution was built, as `YY.MM.DD` with
month and day zero-padded. So `0.5.2+26.09.01` is SciBmad 0.5.2, built on 1 September 2026.

## Running the Distribution

- If installed with conda, run `scibmad`. This starts Julia in the terminal.

- If installed from an installer, run the `SciBmadDistribution` app. This should open a
  Julia window.

- In Julia, the command `using SciBmad` will load the Distribution.

The `Distribution` bundles SciBmad, associated packages, and Julia itself into one binary executable.
When you startup Julia with the command `scibmad`, you are running the Distribution binary.
If you startup Julia with the command `julia`, you are running the standard Julia binary.
It is important not to confuse the two. When you are in Julia, you can see which binary is being used
using the command `Sys.BINDIR`. The result when running standard Julia is something like:
```julia
julia> Sys.BINDIR
"/Users/dcs32/.julia/juliaup/julia-1.12.7+0.aarch64.apple.darwin14/Julia-1.12.app/Contents/Resources/julia/bin"
```
When using the Distribution the result is something like:
```julia
julia> Sys.BINDIR
"/Users/dcs16/miniconda3/libexec/scibmad/bin"
```

Packages the user installs with `Pkg` go in a per-user directory outside the conda
environment (`~/.local/share/scibmad`, or `%LOCALAPPDATA%\scibmad` on Windows), so they
survive removing and recreating the environment. Set `USER_DATA` before launching to put
them somewhere else.

### Which versions am I running?

`versions()` prints the bundled packages and their versions:

```julia
julia> versions()
  ADTypes                     1.24.0
  AtomicAndPhysicalConstants  0.11.5
  BeamTracking                0.8.1
  Beamlines                   0.10.3
  ...
  SciBmad                     0.5.2
```

`versions("makie")` filters by name, and `versions(all = true)` adds every dependency as
well, several hundred of them. It returns the `name => version` pairs it printed, so the
result can be used programmatically.

Note that `Pkg.status()` does *not* answer this question. The bundled packages live in
their own project, so what it reports is your own project, which on a fresh install is
empty. Use `versions()` instead. And make sure you are running the distribution's Julia --
`scibmad`, or the app -- rather than another Julia you have installed, which knows nothing
about any of this.

## Setting up the Distribution for use from Jupyter

`IJulia` is bundled, so the Distribution can serve as a Jupyter **kernel**. Jupyter itself is not
bundled — use whichever Jupyter installation you already have. 

If Jupyter is not yet installed, install with the command:
```bash
conda install -c conda-forge jupyterlab   # or: pip install jupyterlab
```

**Registering the kernel with installkernel is required.** 
To register the Distribution kernel do the following after running the `scibmad` binary 
(and not the standard julia binary!):
```julia
using IJulia
installkernel("SciBmad Distribution";     # Register the SciBmad-Distribution kernel
                     specname = "scibmad-distribution",
                     displayname = "SciBmad Distribution")
```
This registration only needs to be done once and only needs to be redone if the registration is
deleted or a different Conda environment is used.

The `installkernel` function writes a kernel specification into the Jupyter data directory
and not inside the Distribution itself. With this, `SciBmad Distribution` appears in Jupyter's
kernel list and using this kernel with a notebook eliminates any precompilation wait.
Which kernel a notebook is using is shown in the top right of the notebook window, and can
be changed from the *Kernel* menu. To see what kernels are registered, run this in a Unix
command line:
```bash
jupyter kernelspec list | grep -B 1 -A 3 resource_dir
```
This prints a list of registered kernels and the associated paths to the kernels.

### Starting Jupyter

Since the Distribution kernel is registered directly with Jupyter,
Jupyter can be started from either the standard Julia executable (using the `julia` command)
or the Distribution executable (using the `scibmad` command) with:
```julia
using IJulia
notebook()                                # Starts Jupyter server in browser or can use...
jupyterlab()                              #   the more modern interface.
```
Starting Jupyter this way still does not choose a kernel for you. Pick
`SciBmad Distribution` from the kernel list once the notebook opens, or the notebook runs
whatever kernel it defaults to.

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

## Conda packaging

The conda package is built and published by a separate workflow from the installers, in
`.github/workflows/Conda.yml`, from the recipe and staging driver under `meta/conda/`. It
publishes to the `bmad-sim` channel on anaconda.org.

To publish a release: in GitHub under `Actions`, press `Build and Publish Conda Packages`,
then `Run workflow`, and tick `publish`. Left unticked, the run builds and tests every
platform and leaves the packages as workflow artifacts, which is the way to check a change
without putting anything on the channel. The same workflow runs automatically when a
release is created. Two other inputs are useful:

- `platforms` takes a comma-separated list instead of `all`, so one target can be rebuilt
  without waiting on the other four -- each job spends over an hour precompiling. The
  names are `macos-x86_64`, `macos-aarch64`, `linux-x86_64`, `linux-aarch64` and
  `windows-x86_64`, not the conda subdir names.
- `artifacts_from_run` takes the ID of an earlier run and publishes the packages that run
  produced, skipping the builds entirely. This is for when the packages are fine and only
  the upload failed; it turns a three-hour retry into a two-minute one.

Some things about this are not obvious from the files:

- `meta/conda/stage.jl` calls `AppBundler`'s `JuliaImg.stage` directly rather than going
  through `AppBundler.main`. The DMG, MSIX and Snap paths each wrap the same payload in a
  differently shaped container, while `stage` is the step underneath all of them, so
  calling it gives one layout on every platform and skips code signing -- which a conda
  package neither needs nor wants, since an absent signature is nothing for Gatekeeper to
  reject.

- The payload is staged with `RUNTIME_MODE=MIN`, not the `SANDBOX` the installers use.
  SANDBOX has `AppEnv` locate the per-user depot through the container it assumes it is
  running in, and a conda install is in no container: outside one, the Snap and MSIX code
  paths both fall back to a temporary directory, and anything the user installed with
  `Pkg` would be gone by the next session. MIN reads `USER_DATA` from the environment on
  every platform, and the `bin/scibmad` launcher points it at a persistent per-user path
  outside the prefix.

- Symlinks are resolved into copies on Windows only. The payload carries around 500
  relative symlinks from Julia package sources, and they cannot survive the copy into the
  prefix there. They also need a privilege to create that a user installing the package
  may not have.

- Every matrix entry names its conda subdir explicitly. rattler-build otherwise infers it
  from the machine it is running on, which is wrong for the macOS targets because both are
  cross-built on an arm64 runner -- an x86_64 payload would be published as `osx-arm64`,
  and installed on machines that cannot run it.

- The upload deliberately does not pass `--force`, so republishing a version that is
  already on the channel fails rather than silently replacing what people have installed.
  Bump the version instead, or remove the old files on anaconda.org first.

- Publishing needs an `ANACONDA_API_TOKEN` repository secret holding a token created from
  inside the `bmad-sim` organization on anaconda.org, with "Allow write access to the API
  site" enabled. A token made from a personal account has no rights in the organization's
  namespace and fails with a 401 that reads like a missing secret. The workflow passes it
  to rattler-build as `ANACONDA_API_KEY`, which is the name rattler-build reads.

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

## Old Stuff

### App Installation (Not Recommended!)

Conda is recommended because the app installers below are signed with a self-signed
certificate, which both Windows and macOS refuse to trust without the manual steps
described there. A conda package carries no signature for them to reject. 

The app installation installs an app into the standard area. Startup means running the app
instead of using the `scibmad` command from the terminal with a Conda install.

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
  dmg file you downloaded in the second line (the other lines do not need to be modified):
  ```bash
  sudo rm -rf /Applications/SciBmadDistribution.app
  hdiutil attach ~/Downloads/scibmaddistribution-26.8.26-aarch64.dmg
  ditto "/Volumes/SciBmadDistribution Installer/SciBmadDistribution.app" /Applications/SciBmadDistribution.app
  hdiutil detach "/Volumes/SciBmadDistribution Installer"
  sudo xattr -dr com.apple.quarantine /Applications/SciBmadDistribution.app
  sudo chmod -R a-w /Applications/SciBmadDistribution.app
  ```
  This may take a minute or two. Note: The `sudo` commands will ask for a password.

  The first line matters when upgrading and is harmless on a first install. `ditto` copies
  *into* an existing directory rather than replacing it, so any file the old version had and
  the new one does not survives inside the new bundle. A file that is not in the app's
  signature is exactly what breaks it: the app then fails to launch with no error at all, in
  the way described under "Notes" below. Upgrading from a version that bundled a package the
  new one drops — `Revise` was removed after 26.8.23 — hits this. Deleting the old app first
  avoids it.


