cd(@__DIR__)

using DataFrames, CSV, Dates

excess_csv = "us_excess_mortality.csv"
provisional_csv = "2020_provisional.csv"

us_excess = CSV.read("us_excess_mortality.csv")

# struct MyDate
#     day::Int
#     mo::Int
#     yr::Int
# end


# function pseudo_date(a::Date)
#     return a.yr * 10_000 + a.mo * 100 + a.day
# end

# import Base.isless
# function isless(a::Date, b::Date)
#     return pseudo_date(a) < pseudo_date(b)
# end

# import Base.isgreater
# function isgreater(a::Date, b::Date)
#     return pseudo_date(a) > pseudo_date(b)
# end

# import Base.isequal
# function isequal(a::Date, b::Date)
#     return a.day == b.day && a.mo == b.mo && a.yr == b.yr
# end



function parse_date(s::String)
    month, day, year = parse.(Int, split(s, '/'))
    return Date(year, month, day)
end

weighted = "Predicted (weighted)"
all_causes = "All causes"
weighted_inds = findall(isequal(weighted), us_excess.Type)
all_causes_inds = findall(isequal(all_causes), us_excess.Outcome)

inds = intersect(weighted_inds, all_causes_inds)

df = us_excess[inds, :]
dates = parse_date.((df[!, 1]))
n = length(dates)
for i = 2:n
    @assert dates[i] > dates[i - 1]
end

deaths = df[!, 3]

function calculate_deaths(start_date::Date, end_date::Date,
                          dates::Vector{Date}, deaths::Vector{Int})
    first_ind = findfirst(x -> x >= start_date, dates)
    last_ind = findfirst(x -> x > end_date, dates)

    first_prop = ((dates[first_ind] - start_date).value + 1) / 7
    last_prop = 1 - (dates[last_ind] - end_date).value / 7

    total = deaths[first_ind] * first_prop
    for i = (first_ind + 1):(last_ind - 1)
        total += deaths[i]
    end
    total += deaths[last_ind] * last_prop

    # @show dates[first_ind]
    # @show first_prop
    # @show dates[last_ind]
    # @show last_prop

    return total
end

deaths_2018 = calculate_deaths(Date(2018, 1, 1), Date(2018, 12, 31), dates, deaths)
deaths_2019 = calculate_deaths(Date(2019, 1, 1), Date(2019, 12, 31), dates, deaths)
deaths_2020_half = calculate_deaths(Date(2020, 1, 1), Date(2020, 6, 30), dates, deaths)

actual_2018 = 2839205
actual_2019 = 2855000

provisional_2020 = CSV.read(provisional_csv)

actual_2020_half = sum(provisional_2020.provisional_deaths)

err_2018 = deaths_2018 - actual_2018
err_2019 = deaths_2019 - actual_2019
err_2020_half = deaths_2020_half - actual_2020_half

# 2020 deaths calculated using provisional data from January 2020 through
# Jun 2020 + estimated exess mortality from 7/1/2020 through 12/19/2020
# (the last week that is not obviously missing large numbers of deaths) +
# extrapolating the deaths for the last 11 days of December using the weekly
# death count for the week ending on 12/19/2020

deaths_2020 = deaths_2020_half + calculate_deaths(Date(2020, 7, 1), Date(2020, 12, 19), dates, deaths) + 11/7 * deaths[end - 1]

@show deaths_2020;
