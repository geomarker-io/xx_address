library(readr)
library(tidyr)
library(dplyr)
library(lubridate)
library(sf)
library(addr)

# read in data 
raw_data <- read_csv("https://data.cincinnati-oh.gov/api/views/k59e-2pvf/rows.csv?accessType=DOWNLOAD",
                     col_types = cols_only(
                       DATE_FROM = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                       OFFENSE = col_character(),
                       ADDRESS_X = col_character(), 
                       LONGITUDE_X = col_double(),
                       LATITUDE_X = col_double()
                     )) |>
  rename(date_time = DATE_FROM, 
         offense = OFFENSE, 
         address_x = ADDRESS_X,
        lat_jittered = LATITUDE_X, 
        lon_jittered = LONGITUDE_X)

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
  select(-offense) |>
  mutate(
      address_x_spl = purrr::map(address_x, \(x) stringr::str_split_1(x, " ")),
      address_x_num = purrr::map_dbl(address_x_spl, \(x) as.numeric(stringr::str_replace_all(x[1], "X", "0"))+50),
      address_x_street = purrr::map_chr(address_x_spl, \(x) glue::glue_collapse(x[-1], " ")),
      xx_address = purrr::map2_chr(address_x_num, address_x_street, \(x, y) glue::glue("{x} {y}")),
      addr = addr::addr(glue::glue("{xx_address} Anytown XX 00000"))
  ) |>
  select(-address_x_spl, -address_x_num, -address_x_street)

d <- 
  d |>
  mutate(
    tiger_street = addr::addr_match_tiger_street_ranges(
      x = addr, 
      street_only_match = "closest",
      summarize = "union")
  ) |>
  tidyr::unnest(cols = c(tiger_street), keep_empty = TRUE) 

d_dpkg <-
  d |>
  dpkg::as_dpkg(
    name = "crime_incidents",
    title = "Crime Incidents",
    version = "0.1.2",
    homepage = "https://github.com/geomarker-io/xx_address",
    description = paste(readLines(fs::path("crime_incidents", "README", ext = "md")), collapse = "\n")
  )

dpkg::dpkg_gh_release(d_dpkg, draft = FALSE)
