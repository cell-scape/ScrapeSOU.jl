"""
    connect(user::String, pass::String, host::String, port::Int, dbname::String)

Get a database connection

# Arguments
- `user::String`: Postgres Database user
- `pass::String`: User's password
- `host::String`: Hostname
- `port::Int`: port number
- `dbname::String`: Database name

# Returns
- `::LibPQ.Connection`: Postgres Connection

# Examples
```julia
julia> conn = connect("postgres", "postgres", "localhost", 5432, "postgres")

PostgreSQL connection (CONNECTION_OK) with parameters:
  user = postgres
  password = ********************
  channel_binding = prefer
  dbname = postgres
  host = /var/run/postgresql
  port = 5432
  client_encoding = UTF8
  options = -c DateStyle=ISO,YMD -c IntervalStyle=iso_8601 -c TimeZone=UTC
  application_name = LibPQ.jl
  sslmode = prefer
  sslcompression = 0
  sslsni = 1
  ssl_min_protocol_version = TLSv1.2
  gssencmode = prefer
  krbsrvname = postgres
  target_session_attrs = any
```
"""
connect(user::String, pass::String, host::String, port::Int, dbname::String) = LibPQ.Connection("dbname=$dbname user=$user password=$pass port=$port host=$host")

"""
    load_data(df::DataFrame)

Loads a table into the database using DataFrames via STDIN.

# Arguments
- `conn::LibPQ.Connection`: Database Connection
- `df::DataFrame`: A dataframe to load into a database table.

# Returns
- `::Nothing`: nothing

# Examples
```julia
julia> load_data(df)
PostgreSQL Result
```
"""
function load_data(conn, df::DataFrame)
    create_table = """
         CREATE TABLE stateofunion (
             ID INT PRIMARY KEY NOT NULL,
             PRESIDENT TEXT NOT NULL,
             DATE DATE NOT NULL,
             URL TEXT NOT NULL,
             ARTICLE_ID TEXT,
             DATA_HISTORY_NODE_ID TEXT,
             SPEECH TEXT
         );
    """
    LibPQ.execute(conn, create_table)
    row_strings = map(eachrow(df)) do row
        rowstring = String[]

        for field in row
            if ismissing(field)
                push!(rowstring, ",")
            else
                push!(rowstring, string(field))
            end
        end
        join(rowstring, ',')
        push!(rowstring, "\n")
        join(rowstring)
    end
    copyin = LibPQ.CopyIn("COPY stateofunion FROM STDIN (FORMAT CSV);", row_strings)
    LibPQ.execute(conn, copyin)
end


"""
    drop_sou_table(conn::LibPQ.Connection)

Drops the State of Union table.

# Arguments
- `conn::LibPQ.Connection`: Connection to postgres

# Returns
- `::Nothing`: nothing

# Examples
```julia
julia> drop_sou_table(conn)
PostgreSQL Result
```
"""
drop_sou_table(conn::LibPQ.Connection) = LibPQ.execute(conn, "DROP TABLE stateofunion;")


"""
    create_sou_table(conn::LibPQ.Connection)

Creates a table with a default query.

# Arguments
- `conn::LibPQ.Connection`: Connection to Postgres


# Returns
- `::Nothing`: nothing

# Examples
```julia
julia> create_sou_table(conn)
PostgreSQL result
```
"""
function create_sou_table(conn::LibPQ.Connection)
    create_table = """
         CREATE TABLE stateofunion (
             ID INT PRIMARY KEY NOT NULL,
             PRESIDENT VARCHAR(30) NOT NULL,
             DATE DATE NOT NULL,
             URL TEXT,
             ARTICLE_ID VARCHAR(20),
             DATA_HISTORY_NODE_ID INT,
             SPEECH TEXT
        );
    """
    LibPQ.execute(conn, create_table)
end

"""
    load_csv_table(conn::LibPQ.Connection, csvfile::String)

Load data from a CSV file into a table.

# Arguments
- `conn::LibPQ.Connection`: PostgreSQL Connection
- `csvfile::String`: Path to CSV file

# Returns
- `::Nothing`: nothing

# Examples
```julia
julia> load_csv_table(conn, "president_sou_speeches.csv")
PostgreSQL Result
```
"""
function load_csv_table(conn::LibPQ.Connection, csvfile::String)
    load_table = """
        COPY stateofunion(ID, PRESIDENT, DATE, URL, ARTICLE_ID, DATA_HISTORY_NODE_ID, SPEECH)
        FROM '$(abspath(csvfile))'
        DELIMITER ','
        CSV HEADER;
    """
    LibPQ.execute(conn, load_table)
end


"""
    get_sou_table(conn::LibPQ.Connection; limit::Union{Int, Nothing}=nothing)

Retrieve table from Postgres as DataFrame.

# Arguments
- `conn::LibPQ.Connection`: Postgres Connection
- `limit::Union{Int, Nothing}=nothing`: Optional, limit number of rows to return

# Returns
- `::DataFrame`: Database table as DataFrame

# Examples
```julia
julia> df = get_sou_table(conn, limit=5)
Nx10 DataFrame
[...]
```
"""
function get_sou_table(conn::LibPQ.Connection; limit::Union{Int,Nothing}=nothing)::DataFrame
    limit = isnothing(limit) ? "" : "LIMIT $limit"
    q = """
        SELECT * FROM stateofunion $limit;
    """
    LibPQ.execute(conn, q) |> DataFrame
end
