const pymodulehooks = pynew()

function init_stdlib()

    # check word size
    pywordsize = pygt(Bool, pysysmodule.maxsize, Int64(2)^32) ? 64 : 32
    pywordsize == Sys.WORD_SIZE ||
        error("Julia is $(Sys.WORD_SIZE)-bit but Python is $(pywordsize)-bit")

    if C.CTX.is_embedded

        # This uses some internals, but Base._start() gets the state more like Julia
        # is if you call the executable directly, in particular it creates workers when
        # the --procs argument is given.
        # PATCHED FOR SciBmad-Distribution: `ROOT_DIR` is frozen at precompile time to the
        # staging directory of the build machine, where `init.jl` does not exist on the
        # installed machine, so starting Julia from Python (juliacall, e.g. the Python
        # package scibmad) failed with `SystemError: opening file ".../init.jl"`. Locate
        # PythonCall through the load path instead, as the `juliacall.jl` patch does.
        root_dir = let
            path = Base.locate_package(
                Base.PkgId(Base.UUID("6099a3de-0909-46bc-b1f4-468b9a2dfc0d"), "PythonCall"),
            )
            path === nothing ? ROOT_DIR : dirname(dirname(path))
        end
        push!(Base.Core.ARGS, joinpath(root_dir, "pysrc", "juliacall", "init.jl"))
        Base._start()
        Base.eval(:(PROGRAM_FILE = ""))

        # if Python is interactive, ensure Julia is too
        if pyhasattr(pysysmodule, "ps1")
            Base.eval(:(is_interactive = true))
            Base.load_InteractiveUtils()
        end

    else

        # set sys.argv
        pysysmodule.argv = pylist([""; ARGS])

        # some modules test for interactivity by checking if sys.ps1 exists
        if isinteractive() && !pyhasattr(pysysmodule, "ps1")
            pysysmodule.ps1 = ">>> "
        end

        # add hook to perform certain actions when certain modules are loaded
        g = pydict()
        pyexec(
            """
     import sys
     class JuliaCompatHooks:
         def __init__(self):
             self.hooks = {}
         def find_spec(self, name, path=None, target=None):
             hs = self.hooks.get(name)
             if hs is not None:
                 for h in hs:
                     h()
         def add_hook(self, name, h):
             if name not in self.hooks:
                 self.hooks[name] = [h]
             else:
                 self.hooks[name].append(h)
             if name in sys.modules:
                 h()
     JULIA_COMPAT_HOOKS = JuliaCompatHooks()
     sys.meta_path.insert(0, JULIA_COMPAT_HOOKS)
     """,
            g,
        )
        pycopy!(pymodulehooks, g["JULIA_COMPAT_HOOKS"])
    end

end
