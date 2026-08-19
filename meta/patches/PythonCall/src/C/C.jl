"""
    module PythonCall.C

This module provides a direct interface to the Python C API.
"""
module C

using ..Utils

using Base: @kwdef
using UnsafePointers: UnsafePtr
using Libdl:
    dlpath, dlopen, dlopen_e, dlclose, dlsym, dlsym_e, RTLD_LAZY, RTLD_DEEPBIND, RTLD_GLOBAL
using Preferences: @load_preference

# do not load CondaPkg if the exe preference is set to something else
if @load_preference("exe", "@CondaPkg") == "@CondaPkg"
    using CondaPkg: CondaPkg
end

import ..PythonCall:
    python_executable_path, python_library_path, python_library_handle, python_version

include("consts.jl")
include("pointers.jl")
include("extras.jl")
include("context.jl")
include("api.jl")

# --- SciBmad-Distribution patch -------------------------------------------
# See README.md, "Patches".
#
# Left to itself, `init_context` below asks CondaPkg to download and resolve a
# Python environment. Inside this distribution that is wrong twice over: an
# installed bundle is read-only, and during the build the environment resolves
# empty, so initialisation dies with
#
#     Python executable ".../.CondaPkg/.pixi/envs/default/bin/python" does not exist
#
# taking every package that has a PythonCall extension down with it. Point
# PythonCall at the Python_jll interpreter that ships in the bundle instead.
#
# This runs in `__init__` rather than from `meta/startup.jl` because the build
# needs it too: `Pkg.precompile` compiles extensions in worker processes that
# never see a startup file, and loading an extension loads its triggers, which
# runs this `__init__`.
#
# The JLL is loaded every time, even when the environment variables below are
# already set. Loading it is not only how the paths are found: it dlopens the
# interpreter's dependent libraries into this process, and Python needs them
# there. `_ctypes.so`, which `juliacall` imports while initialising, asks the
# dynamic loader for `@rpath/libffi.8.dylib`, which lives in a different
# artifact than the interpreter and resolves only because the JLL has already
# loaded it. Environment variables are inherited by Pkg's precompile workers
# but loaded libraries are not, so a worker that skipped this would find an
# interpreter it cannot import `ctypes` from.
#
# The variables themselves are only filled in when unset, so an explicit
# `JULIA_PYTHONCALL_EXE` still selects the interpreter; an `exe` preference
# wins too, since `Utils.getpref` reads preferences before the environment.
const PYTHON_JLL = Base.PkgId(
    Base.UUID("93d3a430-8e7c-50da-8e8d-3dfcfb3baf05"),
    "Python_jll",
)

function use_bundled_python!()
    # Python_jll has no Windows build, and is absent from projects that do not
    # depend on it. Both are fine; PythonCall then resolves Python as usual.
    Base.locate_package(PYTHON_JLL) === nothing && return
    jll = Base.require(PYTHON_JLL)
    Base.invokelatest(jll.is_available) || return
    get!(ENV, "JULIA_CONDAPKG_BACKEND", "Null")
    get!(ENV, "JULIA_PYTHONCALL_EXE", getfield(jll, :python_path)::String)
    get!(ENV, "JULIA_PYTHONCALL_LIB", getfield(jll, :libpython_path)::String)
    return
end

function __init__()
    try
        use_bundled_python!()
    catch err
        @warn "Could not point PythonCall at the bundled Python interpreter." err
    end
    init_context()
end

end
