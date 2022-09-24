ScrapeSOU
---

Lab 1 for CIS 612, Fall 2022.

Scrapes a website for state of the union addresses.

Multithreaded implementation that accounts for some irregularities in the links.

Loads a Postgres Database from CSV file. 

### Usage

```julia
julia> html = scrape(BASE_PATH * LINKS)
julia> df = scrape_speeches(html)
julia> CSV.write("speeches.csv", df)
julia> conn = connect(USER, PASS, HOST, PORT, DBNAME)
julia> create_sou_table(conn)
julia> load_csv_table(conn, "speeches.csv")
julia> get_sou_table(conn, limit=10)
```

```julia
julia> html = scrape(BASE_PATH * LINKS)
julia> str = scrape_all_to_string(html)
```

```julia
julia> html = scrape(BASE_PATH * LINKS)
julia> local_html_links(html, "index.html")
```