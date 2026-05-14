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

# bring in street range geometries and summarize/unionize overlapping ranges
addr::taf_install("39061", "2025")

tiger_streets <-
  addr::taf_zip(c(
    cincy::zcta_tigris_2010$zcta_2010,
    cincy::zcta_tigris_2020$zcta_2020
  )) |>
  st_as_sf() |>
  arrange(LINEARID, FROMHN) |>
  group_by(
    LINEARID,
    FULLNAME,
    ZIP,
    OFFSET,
    county_fips,
    street_tag_parsed,
    addr_street
  ) |>
  mutate(
    prev_to = lag(cummax(as.numeric(TOHN))),
    new_group = FROMHN > prev_to,
    new_group = replace_na(new_group, FALSE),
    range_id = cumsum(new_group) + 1
  ) |>
  ungroup() |>
  group_by(
    LINEARID,
    FULLNAME,
    ZIP,
    OFFSET,
    county_fips,
    street_tag_parsed,
    addr_street,
    range_id
  ) |>
  summarize(
    FROMHN = min(FROMHN),
    TOHN = max(TOHN),
    s2_geography = st_union(s2_geography)
  ) |>
  select(-range_id) |>
  ungroup() |>
  mutate(addr_string = as.character(addr_street))

# match addr_street from crimes to addr_street in tiger_streets
unique_xx_adds <-
  d |>
  select(xx_address, addr) |>
  group_by(xx_address) |>
  slice(1) |>
  ungroup()

d_matched_range <-
  unique_xx_adds |>
  mutate(
    addr_string = as.character(match_addr_street(
      addr@street,
      tiger_streets$addr_street
    ))
  ) |>
  left_join(tiger_streets, by = "addr_string") |>
  filter(
    FROMHN <= as.numeric(addr@number@digits) &
      TOHN >= as.numeric(addr@number@digits)
  )

unique_xx_adds <-
  left_join(unique_xx_adds, d_matched_range |> select(-addr), by = "xx_address")

d_matched <- left_join(d, unique_xx_adds |> select(-addr), by = "xx_address")

# handle multimatches
# if in same ZIP, union
# if in different ZIP, take closest to jittered coords?
# if in different ZIP but same line, union
d_matched <-
  d_matched |>
  group_by(
    row_id,
    incident_no,
    date_time,
    address_x,
    hate_bias,
    lat_jittered,
    lon_jittered,
    category,
    xx_address,
    addr
  ) |>
  mutate(
    n_matches = ifelse(!is.na(addr_string), n(), 0),
    n_zip = n_distinct(ZIP),
    n_linearid = n_distinct(LINEARID),
    match_type = case_when(
      n_matches == 0 ~ "no_match",
      n_matches == 1 ~ "single_match",
      n_matches > 1 & n_zip == 1 ~ "same_zip",
      n_matches > 1 & n_linearid == 1 & n_zip > 1 ~ "different_zip_same_line",
      n_matches > 1 & n_linearid > 1 & n_zip > 1 ~ "different_zip"
    )
  ) |>
  ungroup()

d_matched |>
  group_by(match_type) |>
  tally() |>
  mutate(pct = n / sum(n) * 100)

d_matched <- split(d_matched, f = d_matched$match_type)

d_matched$no_match <-
  d_matched$no_match |>
  select(-addr) |>
  mutate(addr_street = as.data.frame(addr_street))

d_matched$single_match <-
  d_matched$single_match |>
  select(-addr) |>
  mutate(addr_street = as.data.frame(addr_street))

d_matched$same_zip <-
  d_matched$same_zip |>
  group_by(
    row_id,
    incident_no,
    date_time,
    address_x,
    hate_bias,
    lat_jittered,
    lon_jittered,
    category,
    xx_address,
    addr,
    FULLNAME,
    ZIP,
    county_fips,
    addr_street,
    n_matches,
    n_zip,
    match_type
  ) |>
  summarize(
    FROMHN = min(FROMHN),
    TOHN = max(TOHN),
    s2_geography = st_union(s2_geography)
  ) |>
  ungroup() |>
  select(-addr) |>
  mutate(addr_street = as.data.frame(addr_street))

d_matched$different_zip_same_line <-
  d_matched$different_zip_same_line |>
  group_by(
    row_id,
    incident_no,
    date_time,
    address_x,
    hate_bias,
    lat_jittered,
    lon_jittered,
    category,
    xx_address,
    addr,
    FULLNAME,
    county_fips,
    addr_street,
    n_matches,
    n_zip,
    match_type
  ) |>
  summarize(
    FROMHN = min(FROMHN),
    TOHN = max(TOHN),
    s2_geography = st_union(s2_geography)
  ) |>
  ungroup() |>
  select(-addr) |>
  mutate(addr_street = as.data.frame(addr_street))

# if missing jittered coords, take first
d_matched_diff_zip_missing_coords <-
  d_matched$different_zip |>
  filter(is.na(lat_jittered)) |>
  group_by(
    row_id,
    incident_no,
    date_time,
    address_x,
    hate_bias,
    lat_jittered,
    lon_jittered,
    category,
    xx_address,
    addr,
    FULLNAME,
    county_fips,
    addr_street,
    n_matches,
    n_zip,
    match_type
  ) |>
  # if min distance is tied, take the first one
  slice(1) |>
  ungroup() |>
  select(-addr) |>
  mutate(addr_street = as.data.frame(addr_street))

d_matched_diff_zip <-
  d_matched$different_zip |>
  filter(!is.na(lat_jittered), !is.na(lon_jittered)) |>
  mutate(lat = lat_jittered, lon = lon_jittered) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
  rename(point_geom = geometry) |>
  mutate(
    distance_m = as.numeric(st_distance(
      point_geom,
      s2_geography,
      by_element = TRUE
    ))
  ) |>
  st_drop_geometry() |>
  group_by(
    row_id,
    incident_no,
    date_time,
    address_x,
    hate_bias,
    lat_jittered,
    lon_jittered,
    category,
    xx_address,
    addr,
    FULLNAME,
    county_fips,
    addr_street,
    n_matches,
    n_zip,
    match_type
  ) |>
  filter(distance_m == min(distance_m)) |>
  # if min distance is tied, take the first one
  slice(1) |>
  ungroup() |>
  select(-addr) |>
  mutate(addr_street = as.data.frame(addr_street))

d_matched$different_zip <- bind_rows(
  d_matched_diff_zip_missing_coords,
  d_matched_diff_zip
)

d_matched <-
  bind_rows(d_matched) |>
  arrange(incident_no, date_time) |>
  select(
    -FULLNAME,
    -LINEARID,
    -OFFSET,
    -county_fips,
    -street_tag_parsed,
    -n_matches,
    -n_zip,
    -match_type,
    -distance_m,
    -n_linearid
  )

glimpse(d_matched)

d_dpkg <-
  d_matched |>
  rename(geometry = s2_geography) |>
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
