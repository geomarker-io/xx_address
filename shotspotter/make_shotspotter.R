library(dplyr)
library(sf)
library(addr)
library(stringr)
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
                    DISPOSITION_TEXT = "factor",
                    LONGITUDE_X = readr::col_double(),
                    LATITUDE_X = readr::col_double()
                  )) |>
  rename(date_time = CREATE_TIME_INCIDENT, 
         address_x = ADDRESS_X, 
         dispos = DISPOSITION_TEXT,
         lat_jittered = LATITUDE_X, 
         lon_jittered = LONGITUDE_X)

# exclude data with no response dispositions
d <-
  raw_data |>
  filter(!dispos %in% no_resp_dispos) |>
  select(-dispos) |> 
  tidyr::extract(address_x,
      into = c("x_min", NA, "x_max", NA, "x_name"),
      regex = "(^[0-9X]*)([-]?)([0-9X]*)([ ]*)(.*)",
      remove = FALSE) |>
  mutate(
        across(c(x_max, x_min), na_if, ""),
        across(x_max, coalesce, x_min),
        x_min = as.numeric(gsub("X", "0", x_min)),
        x_max = as.numeric(gsub("X", "9", x_max)),
        x_mid = round((x_min + x_max) / 2),
        x_name = str_to_lower(x_name),
        xx_address = glue::glue("{x_mid} {x_name}"),
        addr = addr::addr(glue::glue("{xx_address} Anytown XX 00000"))
      ) |>
  select(-x_max, -x_min, -x_mid, -x_name)

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
  filter(!is.na(s2_geography)) |>
  mutate(geometry = sf::st_as_sfc(s2_geography)) |>
  select(-s2_geography) |>
  dpkg::as_dpkg(
    name = "shotspotter",
    title = "Shotspotter",
    version = "0.1.2",
    homepage = "https://github.com/geomarker-io/xx_address",
    description = paste(readLines(fs::path("shotspotter", "README", ext = "md")), collapse = "\n")
  )

dpkg::dpkg_gh_release(d_dpkg, draft = FALSE)
