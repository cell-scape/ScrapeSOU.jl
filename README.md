ScrapeSOU
---

Lab 1 for CIS 612, Fall 2022.

Scrapes a website for state of the union addresses.

Multithreaded implementation that accounts for some irregularities in the links.

Loads a Postgres Database from CSV file. 

### Installation

Download and install the latest stable Julia from [JuliaLang.org](https://julialang.org/downloads/) or from the Windows store on Microsoft Windows 10 or higher.

Add this Github repository to your packages in the package manager.

- Enter the Julia REPL from the command line
  - `$ julia`
- Enter the package manager
  - `julia> ]`
  - `(v1.8) pkg> `
- Update your packages
  - `(v1.8) pkg> update`
- Add this repository
  - `(v1.8) pkg> add https://github.com/hairshirt/ScrapeSOU.jl`
- Use the package with `using`
  - `(v1.8) pkg> {backspace}`
  - `julia> using ScrapeSOU`
- You can use an alias for a package name as in Python
  - `julia> import ScrapeSOU as S`
- Most everything can be tab completed, no symbols in Modules are private.
  - `julia> S. {TAB}`
- Every function in this package is documented with docstrings that can be viewed in the `help` mode
  - `julia> ?`
  - `help>`
  - `help>ScrapeSOU`
    - (Shows this README)
  - `help>ScrapeSOU.scrape
    - (Shows description, argument/return types, example usage)

### Usage Examples

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