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
        push!(rowstring, "\n")
        join(rowstring, ',')
    end
    copyin = LibPQ.CopyIn("COPY stateofunion FROM STDIN (FORMAT CSV);", row_strings)
    LibPQ.execute(conn, copyin)
end


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
