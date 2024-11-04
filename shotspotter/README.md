# Shotspotter

<!-- badges: start -->
[![latest github release for shotspotter dpkg](https://img.shields.io/github/v/release/geomarker-io/xx_address?sort=date&filter=shotspotter-*&display_name=tag&label=%5B%E2%98%B0%5D&labelColor=%238CB4C3&color=%23396175)](https://github.com/geomarker-io/xx_address/releases?q=shotspotter&expanded=false)
<!-- badges: end -->

The `shotspotter` data package includes the date and street range locations of gunshots detected by the shotspotter system between August 18, 2017 and January 3, 2023. Shotspotter reports are filtered from all [police calls for service](https://data.cincinnati-oh.gov/safety/PDI-Police-Data-Initiative-Police-Calls-for-Servic/gexm-h6bt) that resulted in a police response and had a known location and date.

Crime incident information includes: 
* `address_x`: the administratively masked location of the shot
* `date_time`: the date/time of the shot
* `lon_jittered` and `lat_jittered`: randomly skewed coordinates (represent the same block area, but not the exact location, of the shot)
* `xx_address`: `address_x` with estimated middle of the street block
* `addr`: the `addr` object for `xx_address`
* `geometry`: the sfc geometry for the geocoded TIGER street range
* `from` and `to`: the minimum and maximum building numbers for the geocoded street range