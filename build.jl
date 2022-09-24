using PackageCompiler

create_app(
    ".",
    "./build",
    force=true,
    precompile_statements_file="precompile.jl",
    cpu_target="generic",
    filter_stdlibs=true,
    sysimage_build_args=Cmd([
        "-O3",
        "--min-optlevel=3",
        "-g0",
        "--threads=auto",
        "--strip-metadata",
    ])
)
