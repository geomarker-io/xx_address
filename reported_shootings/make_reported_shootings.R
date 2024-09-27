library(dplyr)

the_resp <-
  httr2::request("https://data.cincinnati-oh.gov/resource/sfea-4ksu.json") |>
  httr2::req_url_query(`$limit` = 5000) |> # defaults to 1000
  httr2::req_retry() |>
  httr2::req_perform() |>
  httr2::resp_body_json()

out <-
  the_resp |>
  purrr::list_transpose() |>
  stats::setNames(names(the_resp[[1]])) |>
  tibble::as_tibble() |>
  tidyr::unnest(cols = c(streetblock, latitude_x, longitude_x)) |>
  select(
    streetblock, 
    lat_jittered = latitude_x, 
    lon_jittered = longitude_x, 
    date = dateoccurred, 
    race, sex, age, type
  ) |>
  mutate(
    date = as.Date(date, format = "%Y%M%d"),
    xx_address = stringr::str_replace(streetblock, " Block of", ""), 
    xx_address = stringr::str_replace(xx_address, "00", "50")
  ) |>
  select(-streetblock)

d <- 
  out |>
  mutate(
    addr = addr::addr(xx_address),
    tiger_street = addr::addr_match_tiger_street_ranges(
      x = d$addr, 
      summarize = "union")
  ) |>
  tidyr::unnest(cols = c(tiger_street), keep_empty = TRUE) 

d_dpkg <-
  d |>
  dpkg::as_dpkg(
    name = "reported_shootings",
    title = "Reported Shootings",
    version = "0.1.0",
    homepage = "https://github.com/geomarker-io/xx_address",
    description = paste(readLines(fs::path("reported_shootings", "README", ext = "md")), collapse = "\n")
  )

dpkg::dpkg_gh_release(d_dpkg, draft = FALSE)