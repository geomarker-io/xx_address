library(dplyr)
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
  ) |>
  mutate(
    xx_address = stringr::str_remove(xx_address, pattern = " Anytown XX 00000")
  )

library(addr)
source("R/street_range_match.R")

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
out$xx_address[out$xx_address == "NA @ 9"] <- NA

out$addr <- addr::as_addr(out$xx_address)

# match addr_street from crimes to addr_street in tiger_streets
unique_xx_adds <-
  out |>
  select(xx_address, addr) |>
  group_by(xx_address) |>
  slice(1) |>
  ungroup()

d_matched_range <- match_range(d = unique_xx_adds)

unique_xx_adds <-
  left_join(unique_xx_adds, d_matched_range |> select(-addr), by = "xx_address")

d_matched <- left_join(out, unique_xx_adds |> select(-addr), by = "xx_address")

d_matched <- classify_matches(d_matched)

d_matched |>
  group_by(match_type) |>
  tally() |>
  mutate(pct = n / sum(n) * 100)

d_matched <- handle_multimatches(d_matched) |>
  arrange(date, streetblock)

d_dpkg <-
  d_matched |>
  dpkg::as_dpkg(
    name = "reported_shootings",
    title = "Reported Shootings",
    version = "1.0.0",
    homepage = "https://github.com/geomarker-io/xx_address",
    description = paste(
      readLines(fs::path("reported_shootings", "README", ext = "md")),
      collapse = "\n"
    )
  )

dpkg::write_dpkg(d_dpkg, dir = getwd())
dpkg::dpkg_gh_release(d_dpkg, draft = FALSE)
