library(readr)
library(tidyr)
library(dplyr)
library(lubridate)
library(sf)
library(addr)
source("R/street_range_match.R")

# read in data
raw_data <- read_csv(
  "https://data.cincinnati-oh.gov/api/views/k59e-2pvf/rows.csv?accessType=DOWNLOAD",
  col_types = cols_only(
    INCIDENT_NO = col_character(),
    DATE_FROM = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
    OFFENSE = col_character(),
    ADDRESS_X = col_character(),
    LONGITUDE_X = col_double(),
    LATITUDE_X = col_double(),
    HATE_BIAS = col_character()
  )
) |>
  rename(
    incident_no = INCIDENT_NO,
    date_time = DATE_FROM,
    offense = OFFENSE,
    address_x = ADDRESS_X,
    lat_jittered = LATITUDE_X,
    lon_jittered = LONGITUDE_X,
    hate_bias = HATE_BIAS
  )
# same incident, different jittered coords -> combine
# group_by(incident_no, date_time, offense, address_x, hate_bias) |>
# summarize(across(c(lat_jittered, lon_jittered), \(x) {
#   mean(x, na.rm = TRUE)
# })) |>
# ungroup()

min(raw_data$date_time, na.rm = TRUE)
max(raw_data$date_time, na.rm = TRUE)

# clean up and match to coarse crime categories
crime_category <- yaml::read_yaml("crime_incidents/crime_categories.yaml")

crime_category <-
  tibble::tibble(
    category = unlist(purrr::map(crime_category, names)),
    offense = purrr::map(crime_category$category, ~ .x[[1]])
  ) |>
  unnest(cols = offense)

d <-
  raw_data |>
  filter(date_time >= as.Date("2011-01-01")) |> # filter by crime start date
  distinct(.keep_all = TRUE) |> # remove duplicated rows
  filter(!is.na(address_x)) |> # remove missing address
  left_join(crime_category, by = "offense") |> # assign offense crime_category
  select(-offense) |>
  mutate(
    address_x_spl = purrr::map(address_x, \(x) stringr::str_split_1(x, " ")),
    address_x_num = purrr::map_dbl(address_x_spl, \(x) {
      as.numeric(stringr::str_replace_all(x[1], "X", "0")) + 50
    }),
    address_x_street = purrr::map_chr(address_x_spl, \(x) {
      glue::glue_collapse(x[-1], " ")
    }),
    xx_address = purrr::map2_chr(address_x_num, address_x_street, \(x, y) {
      glue::glue("{x} {y}")
    }),
    addr = addr::as_addr(xx_address)
  ) |>
  select(-address_x_spl, -address_x_num, -address_x_street)

d$row_id <- 1:nrow(d)

# match addr_street from crimes to addr_street in tiger_streets
unique_xx_adds <-
  d |>
  select(xx_address, addr) |>
  group_by(xx_address) |>
  slice(1) |>
  ungroup()

d_matched_range <- match_range(d = unique_xx_adds)

unique_xx_adds <-
  left_join(unique_xx_adds, d_matched_range |> select(-addr), by = "xx_address")

d_matched <- left_join(d, unique_xx_adds |> select(-addr), by = "xx_address")

d_matched <- classify_matches(d_matched)

d_matched |>
  group_by(match_type) |>
  tally() |>
  mutate(pct = n / sum(n) * 100)

d_matched <- handle_multimatches(d_matched) |>
  arrange(incident_no, date_time)

d_dpkg <-
  d_matched |>
  dpkg::as_dpkg(
    name = "crime_incidents",
    title = "Crime Incidents",
    version = "1.0.0",
    homepage = "https://github.com/geomarker-io/xx_address",
    description = paste(
      readLines(fs::path("crime_incidents", "README", ext = "md")),
      collapse = "\n"
    )
  )

dpkg::write_dpkg(d_dpkg, dir = getwd())
dpkg::dpkg_gh_release(d_dpkg, draft = FALSE)
