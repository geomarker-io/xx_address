library(dplyr)
library(sf)
source("./street_range_matching.R")
no_resp_dispos <- readRDS("./shotspotter/no_resp_dispos.rds")

shot_spotter_csv_url <-
  glue::glue(
    "https://data.cincinnati-oh.gov/api",
    "/views/gexm-h6bt/rows.csv",
    "?query=select%20*%20where%20(%60incident_type_desc%60%20%3D%20%27SHOT%20SPOTTER%20ACTIVITY%27)",
    "&read_from_nbe=true&version=2.1&accessType=DOWNLOAD"
  )

raw_data <-
  readr::read_csv(shot_spotter_csv_url,
                  col_types = readr::cols_only(
                    ADDRESS_X = "character",
                    CREATE_TIME_INCIDENT = readr::col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                    DISPOSITION_TEXT = "factor"
                  )) |>
  rename(date_time = CREATE_TIME_INCIDENT, 
         address_x = ADDRESS_X, 
         dispos = DISPOSITION_TEXT)

# exclude data with missing address, date, or disposition
d <-
  raw_data |>
  na.omit() |>
  filter(!dispos %in% no_resp_dispos) |>
  select(-dispos) 

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
    group_by(address_x, tlid) |>
    tally() |>
    ungroup() |>
    left_join(d_street_ranges_sf, by = c("address_x", "tlid")) |>
    group_by(tlid, geometry) |>
    summarize(n_gunshots = sum(n)) |>
    relocate(geometry, .after = last_col()) |>
    st_as_sf() |>
    mutate(s2 = st_as_s2(geometry)) |>
    st_drop_geometry()

d_dpkg <-
  d_counts_by_street_range |>
  dpkg::as_dpkg(
    name = "shotspotter",
    title = "Shotspotter",
    version = "0.1.0",
    homepage = "https://github.com/geomarker-io/xx_address",
    description = paste(readLines(fs::path("shotspotter", "README", ext = "md")), collapse = "\n")
  )

dpkg::dpkg_gh_release(d_dpkg, draft = FALSE)
