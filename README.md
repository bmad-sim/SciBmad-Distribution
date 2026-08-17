# SciBmad-Distribution

A Julia distribution that ships [SciBmad](https://github.com/bmad-sim/SciBmad) — the Julia
toolkit for charged particle beam dynamics — together with everything needed to work through
the [SciBmad Ring Design tutorial](https://github.com/bmad-sim/Tutorial-SciBmad-Ring-Design),
precompiled and ready to run. Install it, launch Julia, and `using SciBmad` returns
immediately: no package installation, no first-use compilation wait. Additional packages can
still be installed with `Pkg` without triggering recompilation of the bundled ones.

The distribution is built with [AppBundler.jl](https://github.com/PeaceFounder/AppBundler.jl)
and follows the [Jumbo](https://github.com/JanisErdmanis/Jumbo) template: the `Project.toml`
here has `name` and `version` fields, and every package it lists — plus their dependencies —
is bundled into the stdlib path of the shipped Julia so that they are never accidentally
recompiled.

## What is included

The dependency list is the union of what `SciBmad` itself provides and what the ring design
tutorial notebooks use:

- **SciBmad core**: `SciBmad`, `Beamlines`, `BeamTracking`, `NonlinearNormalForm`, `GTPSA`,
  `TPSAInterface`, `AtomicAndPhysicalConstants`, `FundamentalFrequencies`, `BatchSolve`,
  `KernelAbstractions`
- **Differentiation and arrays**: `ADTypes`, `DifferentiationInterface`, `ForwardDiff`,
  `FiniteDiff`, `StaticArrays`, `TypedTables`
- **Optimization**: `Optim`, `NLSolversBase`, `OptimizationOptimJL`, `OptimizationLBFGSB`
- **Plotting and analysis**: `CairoMakie`, `Plots`, `LaTeXStrings`, `Distributions`
- **Interactive tooling**: `Revise`, `Infiltrator` (both loaded automatically by
  `meta/startup.jl` in interactive sessions)

Julia standard libraries used by the tutorials (`LinearAlgebra`, `Statistics`, `Random`,
`Printf`, `SparseArrays`, `DelimitedFiles`) are always available and are therefore not listed
in `Project.toml`.

`Manifest.toml` records the exact resolved versions. Both it and `meta/Manifest.toml` were
resolved with Julia 1.11, the minimum version this distribution supports, and AppBundler takes
the Julia version to ship inside the bundle from their `julia_version` field.

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

## Building

Install Julia 1.11 or later and install the build dependencies:

```bash
julia --project=meta -e 'using Pkg; Pkg.instantiate()'
```

Then perform the build:

```bash
julia --project=meta -e 'using AppBundler; AppBundler.main(ARGS)' build . --build-dir=build --selfsign
```

Everything after the `-e` expression is passed through to AppBundler's command line. On Julia
1.12 or later the shorter `julia --project=meta -m AppBundler build . --build-dir=build
--selfsign` form works as well, but `-m` does not exist in 1.11, so the invocation above is
the portable one. Pass `AppBundler.main(["--help"])` to see all build options.

This creates build artifacts in the `build` directory. By default the bundle targets the host
platform.

Release assets for all platforms are produced by the **Build Release Assets** GitHub Actions
workflow, which runs automatically when a release is created and can also be started manually
from the Actions tab.

## Cross-platform builds

Bundles for other platforms are created with command options:

```bash
julia --project=meta -e 'using AppBundler; AppBundler.main(ARGS)' build . --build-dir=build --target-arch=aarch64 --target-bundle=dmg -Djuliaimg_precompile=false --selfsign
```

This creates a bundle for the specified platform where precompilation happens on the user's
system at first launch.

## Updating the package set

Edit `Project.toml`, re-resolve, and commit the updated `Manifest.toml`:

```bash
julia --project=. -e 'using Pkg; Pkg.update()'
```

Bump `version` in `Project.toml` (the distribution uses a `YY.M.D` scheme) and tag a release
to publish new installers.
