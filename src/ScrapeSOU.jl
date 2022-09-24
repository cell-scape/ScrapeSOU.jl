
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
    s = ArgParseSettings(prog="ScrapeSOU", description="Scrapes State of Union addresses from a website", epilog="---", autofix_names=true)
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
        "--local-speeches"
            help = "Create landing page and local copies of the speeches"
            action = :store_true
        "--user", "-u"
            help = "Postgres Username"
            arg_type = String
            default = "postgres"
        "--pass", "-p"
            help = "Postgres Password"
            arg_type = String
            default = "postgres"
        "--host"
            help = "Hostname/path"
            arg_type = String
            default = "/var/run/postgresql"
        "--port"
            help = "Port"
            arg_type = Int
            default = 5432
        "--dbname", "-d"
            help = "Database name"
            arg_type = String
            default = "postgres"
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
    conn = connect(args[:user], args[:pass], args[:host], args[:port], args[:dbname])
    try
        @info "Getting list of links..."
        html = scrape(BASE_PATH * LINKS)
        if args[:local_speeches]
            @info "Creating local index.html and speeches directory"
            local_html_links(html, "index.html")
            return 0
        end
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
        LibPQ.execute(conn, "DROP TABLE stateofunion;")
        @info "Create table..."
        create_sou_table(conn)
        @info "Load table with CSV data..."
        load_csv_table(conn, args[:csvout])
        limit = get(args, :limit, nothing)
        @info "Test table in Postgres..."
        println(get_sou_table(conn, limit=limit))
        close(conn)
    catch
        close(conn)
        ex = stacktrace(catch_backtrace())
        @error "ScrapeSOU failed:" ex
        return -1
    end
    return 0
end

end
