const pyjuliacallmodule = pynew()
const pyJuliaError = pynew()
const CPyExc_JuliaError = Ref(C.PyNULL)

function init_juliacall()
    # ensure the 'juliacall' module exists
    # this means that Python code can do "import juliacall" and it will work regardless of
    # whether Python is embedded in Julia or vice-versa
    jl = pyjuliacallmodule
    sys = pysysmodule
    os = pyosmodule
    # PATCHED FOR SciBmad-Distribution: `ROOT_DIR` is `dirname(dirname(@__DIR__))`,
    # which is frozen at precompile time. AppBundler precompiles into a staging
    # directory and the bundle is then installed somewhere else, so the baked path
    # no longer exists and juliacall cannot be found. Locating the package through
    # the load path instead resolves it wherever the bundle is actually installed.
    # `pkgdir`/`pathof` cannot be used here: this runs during PythonCall's own
    # `__init__`, before the package's origin is registered, so they return
    # `nothing`. Falls back to the baked constant if the lookup fails.
    root_dir = let
        path = Base.locate_package(
            Base.PkgId(Base.UUID("6099a3de-0909-46bc-b1f4-468b9a2dfc0d"), "PythonCall"),
        )
        path === nothing ? ROOT_DIR : dirname(dirname(path))
    end
    if C.CTX.is_embedded
        # in this case, Julia is being embedded into Python by juliacall, which already exists
        pycopy!(jl, sys.modules["juliacall"])
        @assert pystr_asstring(jl.__version__) == string(VERSION)
    elseif "juliacall" in sys.modules
        # otherwise, Python is being embedded into Julia by PythonCall, so should not exist
        error("'juliacall' module already exists")
    else
        # TODO: Is there a more robust way to import juliacall from a specific path?
        # prepend the directory containing juliacall to sys.path
        sys.path.insert(0, joinpath(root_dir, "pysrc"))
        # prevent juliacall from initialising itself
        os.environ["PYTHON_JULIACALL_INIT"] = "no"
        # import juliacall
        pycopy!(jl, pyimport("juliacall"))
        # check the version
        @assert realpath(pystr_asstring(jl.__path__[0])) ==
                realpath(joinpath(root_dir, "pysrc", "juliacall"))
        @assert pystr_asstring(jl.__version__) == string(VERSION)
        @assert !pybool_asbool(jl.CONFIG["init"])
    end
    pycopy!(pyJuliaError, jl.JuliaError)
    CPyExc_JuliaError[] = incref(getptr(pyJuliaError))
end
