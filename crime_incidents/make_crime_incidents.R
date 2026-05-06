library(readr)
library(tidyr)
library(dplyr)
library(lubridate)
library(sf)
library(addr)

# read in data
raw_data <- read_csv(
  "https://data.cincinnati-oh.gov/api/views/k59e-2pvf/rows.csv?accessType=DOWNLOAD",
  col_types = cols_only(
    DATE_FROM = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
    OFFENSE = col_character(),
    ADDRESS_X = col_character(),
    LONGITUDE_X = col_double(),
    LATITUDE_X = col_double(),
    HATE_BIAS = col_character()
  )
) |>
  rename(
    date_time = DATE_FROM,
    offense = OFFENSE,
    address_x = ADDRESS_X,
    lat_jittered = LATITUDE_X,
    lon_jittered = LONGITUDE_X,
    hate_bias = HATE_BIAS
  )

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

tiger_street_ranges <- tiger_addr_feat("39061", year = "2025") |>
  st_as_sf()

tiger_street_names <- tiger_feat_names("39061", "2025") |>
  mutate(addr_street_string = as.character(addr_street))

d_lineid <-
  d |>
  mutate(
    addr_street_string = as.character(match_addr_street(
      addr@street,
      tiger_street_names$addr_street
    ))
  ) |>
  left_join(tiger_street_names, by = "addr_street_string")

d_matched_range <-
  d_lineid |>
  left_join(tiger_street_ranges, by = "LINEARID") |>
  filter(FROMHN < addr@number@digits, TOHN > addr@number@digits) |>
  group_by(date_time, address_x) |>
  summarize(
    from = min(FROMHN),
    to = max(TOHN),
    s2_geography = sf::st_union(s2_geography)
  )

d <- left_join(d, d_matched_range, by = c("date_time", "address_x"))

d_dpkg <-
  d |>
  rename(geometry = s2_geography) |>
  select(-addr) |>
  dpkg::as_dpkg(
    name = "crime_incidents",
    title = "Crime Incidents",
    version = "0.2.0",
    homepage = "https://github.com/geomarker-io/xx_address",
    description = paste(
      readLines(fs::path("crime_incidents", "README", ext = "md")),
      collapse = "\n"
    )
  )

dpkg::write_dpkg(d_dpkg, dir = getwd())
dpkg::dpkg_gh_release(d_dpkg, draft = FALSE)
