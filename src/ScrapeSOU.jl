
module ScrapeSOU

using ArgParse
using Cascadia
using CSV
using DataFrames
using DataFramesMeta
using DataStructures
using Dates
using Gumbo
using HTTP
using LibPQ

include("constants.jl")
include("scrape.jl")
include("db.jl")

export BASE_PATH, LINKS, LEADER, CONN, DATEFMT
export scrape, scrape_speeches, scrape_speech, scrape_all_to_string

"""
    argparser()

Sets up CLI argument parser.

# Arguments
- None

# Returns
- `::ArgParseSettings`: ArgParseSettings object

# Examples
```julia
julia> argparser()
ArgParseSettings([...]
```
"""
function argparser()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--string", "-s"
            help = "Dump as a string"
            action = :store_true
        "--csvout", "-c"
            help = "Output path for CSV file"
            arg_type = String
            default = "presidential_sou_speeches.csv"
        "--limit", "-l"
            help = "Record limit for Select query"
            arg_type = Int
    end
    return s
end

"""
    julia_main()::Cint

Binary entrypoint. Processes command line arguments
with argparser.

# Arguments
- None

# Returns
- `::Cint`: A C ABI Compatible integer return code

# Examples
```julia
julia> julia_main()
0
```
"""
function julia_main()::Cint
    ap = argparser()
    args = parse_args(ARGS, ap, as_symbols=true)
    try
        @info "Getting list of links..."
        html = scrape(BASE_PATH * LINKS)
        if args[:string]
            @info "Scraping speeches and dumping to string..."
            s = scrape_all_to_string(html)
            println(s)
            return 0
        end
        @info "Scraping speeches..."
        df = scrape_speeches(html)
        @info "Writing CSV file..."
        CSV.write(args[:csvout], df)
        @info "Dropping table if exists..."
        LibPQ.execute(CONN, "DROP TABLE stateofunion;")
        @info "Create table..."
        create_sou_table(CONN)
        @info "Load table with CSV data..."
        load_csv_table(CONN, args[:csvout])
        limit = get(args, :limit, nothing)
        @info "Test table in Postgres..."
        println(get_sou_table(CONN, limit=limit))
    catch
        ex = stacktrace(catch_backtrace)
        @error "ScrapeSOU failed:" ex
        return -1
    end
    return 0
end

end
