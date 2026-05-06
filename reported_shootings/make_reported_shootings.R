library(dplyr)
library(addr)
library(sf)

# using the API now only goes back to 2023
# use old version to keep data back to 2021
reported_shootings_v0.1.0 <- dpkg::stow(
  "https://github.com/geomarker-io/xx_address/releases/download/reported_shootings-v0.1.0/reported_shootings-v0.1.0.parquet"
) |>
  arrow::read_parquet() |>
  select(
    streetblock,
    xx_address,
    lat_jittered,
    lon_jittered,
    date,
    race,
    sex,
    age,
    type
  )

min(reported_shootings_v0.1.0$date, na.rm = TRUE)
max(reported_shootings_v0.1.0$date, na.rm = TRUE)

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
    race,
    sex,
    age,
    type
  ) |>
  mutate(
    date = as.Date(date, format = "%Y%M%d"),
    streetblock_spl = purrr::map(streetblock, \(x) {
      stringr::str_split_1(x, " Block of ")
    }),
    streetblock_num = purrr::map_dbl(streetblock_spl, \(x) {
      as.numeric(x[1]) + 50
    }),
    xx_address = purrr::map2_chr(streetblock_num, streetblock_spl, \(x, y) {
      glue::glue("{x} {y[2]}")
    })
  ) |>
  select(streetblock, xx_address, lat_jittered:type)

min(out$date, na.rm = TRUE)
max(out$date, na.rm = TRUE)

# join old and new data
out <-
  bind_rows(
    as_tibble(
      reported_shootings_v0.1.0 |>
        filter(date < min(out$date))
    ),
    out
  )

# problematic address (I- Block of @ 9)
out$xx_address[764] <- NA

d <-
  out |>
  mutate(
    xx_address = stringr::str_remove(xx_address, pattern = " Anytown XX 00000"),
    addr = addr::as_addr(xx_address)
  )

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
  group_by(date, xx_address) |>
  summarize(
    from = min(FROMHN),
    to = max(TOHN),
    s2_geography = sf::st_union(s2_geography)
  )

d <- left_join(d, d_matched_range, by = c("date", "xx_address"))


d_dpkg <-
  d |>
  rename(geometry = s2_geography) |>
  select(-addr) |>
  dpkg::as_dpkg(
    name = "reported_shootings",
    title = "Reported Shootings",
    version = "0.2.0",
    homepage = "https://github.com/geomarker-io/xx_address",
    description = paste(
      readLines(fs::path("reported_shootings", "README", ext = "md")),
      collapse = "\n"
    )
  )

dpkg::write_dpkg(d_dpkg, dir = getwd())
dpkg::dpkg_gh_release(d_dpkg, draft = FALSE)
