# add suffixes to the end of these specific city street names to match tigris street names
add_suffix <-
  list(
    "ave" = c("e mcmicken", "w mcmicken", "mcgregor", "st james", "blair", "mckeone"))

suffix_replacements <-
  paste(add_suffix$ave, names(add_suffix["ave"])) |>
  purrr::set_names(add_suffix$ave)

make_street_range <- function(address_x) {
  d <- tibble::tibble(address_x = address_x)
  
# special case for hyphenated street ranges
  d_hyph_str <- 
    d |>
    dplyr::select(address_x) |>
    dplyr::filter(stringr::str_detect(address_x, "-"), 
                  stringr::str_detect(address_x, "^[0-9]")) |>
    tidyr::separate_wider_regex(cols = address_x, 
                                patterns = c(x_min = "^[0-9X-]*", x_name = ".*"),
                                cols_remove = FALSE
    ) |>
    dplyr::mutate(x = stringr::str_split(x_min, "-"), 
                  x_min = purrr::map_chr(x, ~.x[1]), 
                  x_max = purrr::map_chr(x, ~.x[2])) |>
    select(-x)
  
d_single_str <- 
    d |>
    dplyr::select(address_x) |>
    dplyr::filter(!address_x %in% d_hyph_str$address_x) |>
    # separate street numbers from street name
    tidyr::separate_wider_regex(cols = address_x, 
                         patterns = c(x_min = "^[0-9X]*", x_name = ".*"),
                         cols_remove = FALSE
    ) |>
    dplyr::mutate(x_max = x_min)
  
d_hyph_str |>
    dplyr::bind_rows(d_single_str) |>
    dplyr::mutate(x_name = stringr::str_trim(x_name), # remove leading whitespace 
           # create min and max street range
           x_min = as.numeric(stringr::str_replace_all(x_min, "X", "0")), 
           x_max = as.numeric(stringr::str_replace_all(x_max, "X", "9")),
           # clean up street names to match tigris street names
           x_name = stringr::str_to_lower(x_name), 
           x_name = stringr::str_replace_all(x_name, stringr::fixed(" av"), " ave"),
           x_name = stringr::str_replace_all(x_name, stringr::fixed(" wy"), " way"),
           x_name = stringr::str_replace_all(x_name, stringr::fixed("east "), "e "),
           x_name = stringr::str_replace_all(x_name, suffix_replacements),
           x_name = stringr::str_replace_all(x_name, stringr::fixed("ave ave"), "ave")
    ) |>
    dplyr::select(address_x, x_min, x_max, x_name)
}

tigris_streets <- readRDS("tigris_streets.rds")

# returns all "intersecting" tigris street range address lines within intput street name and min/max for street number
query_street_ranges <- function(x_name, x_min, x_max, ...) {
  ## find street
  streets_contain <-
    tigris_streets |>
    dplyr::filter(name == x_name)
  ## return range that contains both min and max street number, if available
  range_contain <-
    streets_contain |>
    dplyr::filter(number_min < x_min & number_max > x_max) 
  if (nrow(range_contain) > 0) return(range_contain)
  # if not available, return ranges containing either the min or max street number
  range_partial <-
    streets_contain |>
    dplyr::filter(between(number_min, x_min, x_max) |
             between(number_max, x_min, x_max))
  if (nrow(range_partial) > 0) return(range_partial)
  # if nothing available, return NA
  return(tibble::tibble(
    name = NA,
    tlid = NA,
    number_min = NA, 
    number_max = NA, 
    geometry = NA
  ))
}

