# Reported Shootings

<!-- badges: start -->
[![latest github release for reported_shootings dpkg](https://img.shields.io/github/v/release/geomarker-io/xx_address?sort=date&filter=reported_shootings-*&display_name=tag&label=%5B%E2%98%B0%5D&labelColor=%238CB4C3&color=%23396175)](https://github.com/geomarker-io/xx_address/releases?q=reported_shootings&expanded=false)
<!-- badges: end -->

The `reported shootings` data package includes the date and street range locations of reported shootings from the [Cincinnati Police Department](https://data.cincinnati-oh.gov/safety/CPD-Reported-Shootings/sfea-4ksu/about_data) reported between November 1, 2021 and May 30, 2026. This dataset captures confirmed shooting events in the City of Cincinnati. Shootings events are captured in the Computer Aided Dispatch System (CAD), and are ultimately stored in the City's Records Management System (RMS). 

Shootings events records include the `streetblock` where the incident occurred (e.g., "1700 Block of RACE ST"). The `streetblock` is transformed to an address to represent the middle of that block (e.g., "1750 RACE ST") and geocoded to a TIGER street range using [`addr`](https://github.com/cole-brokamp/addr).

Shooting events are recorded at the victim level and contain information on:
* `streetblock`: text field describing the block where the incident occurred 
* location (`lat_jittered` and `lon_jittered`): randomly skewed coordinates (represent the same block area, but not the exact location, of the incident)
* `date`: the date the event occurred
* `race`: the race of the victim
* `sex`: the sex of the victim
* `age`: the age of the vicitim
* `type`: `FATAL` or `NONFATAL`
* `xx_address`: the address corresponding to the middle of the block where the incident occurred
* `s2_geography`: the sfc geometry for the geocoded TIGER street range
* `FROMHN` and `TOHN`: the minimum and maximum building numbers for the geocoded street range
* `addr_string`: the name of the matched TIGER street
* `ZIP`: zipcode that contains the matched TIGER street
* `addr_street`: addr_street components (see geomarker.io/addr)


