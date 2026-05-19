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
    new_group = tidyr::replace_na(new_group, FALSE),
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

match_range <- function(d) {
  d |>
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
}

classify_matches <- function(d) {
  d |>
    group_by(across(
      -c(
        LINEARID,
        FULLNAME,
        ZIP,
        OFFSET,
        county_fips,
        street_tag_parsed,
        addr_street,
        FROMHN,
        TOHN,
        s2_geography
      )
    )) |>
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
}

handle_multimatches <- function(d_matched) {
  d_matched <-
    d_matched |>
    select(-addr) |>
    mutate(addr_street = as.data.frame(addr_street))

  d_matched <- split(d_matched, f = d_matched$match_type)

  d_matched$same_zip <-
    d_matched$same_zip |>
    group_by(group_by(across(-c(LINEARID, FROMHN, TOHN, s2_geography)))) |>
    summarize(
      FROMHN = min(FROMHN),
      TOHN = max(TOHN),
      s2_geography = st_union(s2_geography)
    ) |>
    ungroup()

  d_matched$different_zip_same_line <-
    d_matched$different_zip_same_line |>
    group_by(group_by(across(-c(ZIP, FROMHN, TOHN, s2_geography)))) |>
    summarize(
      FROMHN = min(FROMHN),
      TOHN = max(TOHN),
      s2_geography = st_union(s2_geography)
    ) |>
    ungroup()

  # if missing jittered coords, take first
  if (any(is.na(d_matched$different_zip$lat_jittered))) {
    d_matched_diff_zip_missing_coords <-
      d_matched$different_zip |>
      filter(is.na(lat_jittered)) |>
      group_by(across(
        -c(LINEARID, ZIP, FROMHN, TOHN, s2_geography)
      )) |>
      slice(1) |>
      ungroup()
  } else {
    d_matched_diff_zip_missing_coords <- tibble::tibble()
  }

  d_matched$different_zip <-
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
    group_by(across(
      -c(
        LINEARID,
        ZIP,
        FROMHN,
        TOHN,
        s2_geography,
        street_tag_parsed,
        distance_m
      )
    )) |>
    filter(distance_m == min(distance_m)) |>
    # if min distance is tied, take the first one
    slice(1) |>
    ungroup()

  # if missing jittered coords, take first
  if (nrow(d_matched_diff_zip_missing_coords) > 0) {
    d_matched$different_zip <- bind_rows(
      d_matched$different_zip,
      d_matched_diff_zip_missing_coords
    )
  }

  bind_rows(d_matched) |>
    select(
      -FULLNAME,
      -LINEARID,
      -OFFSET,
      -county_fips,
      -street_tag_parsed,
      -n_matches,
      -n_zip,
      -match_type,
      -n_linearid
    )
}
