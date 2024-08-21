library(readr)
library(tidyr)
library(dplyr)
library(lubridate)
library(sf)
source("./street_range_matching.R")

# read in data 
raw_data <- read_csv("https://data.cincinnati-oh.gov/api/views/k59e-2pvf/rows.csv?accessType=DOWNLOAD",
                     col_types = cols_only(
                       DATE_FROM = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                       OFFENSE = col_character(),
                       ADDRESS_X = col_character()
                     )) |>
  rename(date_time = DATE_FROM, 
         offense = OFFENSE, 
         address_x = ADDRESS_X)

# clean up and match to coarse crime categories
crime_category <- yaml::read_yaml("crime_incidents/crime_categories.yaml")
  
crime_category <- 
  tibble::tibble(category = unlist(purrr::map(crime_category, names)), 
                 offense = purrr::map(crime_category$category, ~.x[[1]])) |>
  unnest(cols = offense)

d <- 
  raw_data |> 
  filter(date_time >= as.Date("2011-01-01")) |>    # filter by crime start date
  distinct(.keep_all = TRUE) |> # remove duplicated rows
  filter(!is.na(address_x)) |> # remove missing address
  left_join(crime_category, by = "offense") |> # assign offense crime_category
  select(-offense)

# transform city street range (12XX) to tigris street range (1200-1299)
d_street_ranges <- make_street_range(unique(d$address_x))

# match street ranges
d_street_ranges$street_ranges <-
  purrr::pmap(d_street_ranges, 
              query_street_ranges, 
              .progress = "querying street ranges")

# reduce to one geometry per city street range
d_street_ranges_sf <- 
  tidyr::unnest(d_street_ranges, cols = c(street_ranges)) |>
  filter(!is.na(tlid)) |>
  group_by(address_x, x_min, x_max, x_name) |>
  summarize(tlid = paste(unique(tlid), collapse = "-"), 
            geometry = st_union(geometry)) |>
  st_as_sf()

d <- left_join(d, 
  d_street_ranges_sf |> select(address_x, tlid) |> st_drop_geometry(), 
  by = "address_x")

d_counts_by_street_range <- 
  d |>
  filter(!is.na(tlid)) |>
  group_by(address_x, tlid, category) |>
  tally() |>
  pivot_wider(names_from = category, 
              values_from = n) |>
  ungroup() |>
  left_join(d_street_ranges_sf, by = c("address_x", "tlid")) |>
  group_by(tlid, geometry) |>
  summarize(across(property:other, sum)) |>
  relocate(geometry, .after = last_col()) |>
  st_as_sf()

d_dpkg <-
  d_counts_by_street_range |>
  dpkg::as_dpkg(
    name = "crime_incidents",
    title = "Crime Incidents",
    version = "0.1.0",
    homepage = "https://github.com/geomarker-io/xx_address",
    description = paste(readLines(fs::path("crime_incidents", "README", ext = "md")), collapse = "\n")
  )

dpkg::dpkg_gh_release(d_dpkg, draft = FALSE)

