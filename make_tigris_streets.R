library(dplyr)
library(stringr)
library(sf)

# https://www2.census.gov/geo/pdfs/maps-data/data/tiger/tgrshp2020/TGRSHP2020_TechDoc.pdf
tigris_streets <-
  tigris::address_ranges(state = "39", county = "061", year = 2022) |>
  select(tlid = TLID,
         name = FULLNAME,
         LFROMHN, RFROMHN,
         LTOHN, RTOHN) |>
  mutate(across(ends_with("HN"), as.numeric)) |>
  dplyr::rowwise() |>
  transmute(name = str_to_lower(name),
            tlid = as.character(tlid),
            number_min = min(LFROMHN, RFROMHN, LTOHN, RTOHN, na.rm = TRUE),
            number_max = max(LFROMHN, RFROMHN, RTOHN, LTOHN, na.rm = TRUE)) |>
  ungroup()

saveRDS(tigris_streets, "tigris_streets.rds")
