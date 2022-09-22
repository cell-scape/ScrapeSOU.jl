module ScrapeSOU

using Cascadia
using CSV
using DataFrames
using DataFramesMeta
using Gumbo
using HTTP

include("constants.jl")
include("scrape.jl")

export URL, scrape

end
