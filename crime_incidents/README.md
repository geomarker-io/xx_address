# Crime Incidents

<!-- badges: start -->
[![latest github release for crime_incidents dpkg](https://img.shields.io/github/v/release/geomarker-io/xx_address?sort=date&filter=crime_incidents-*&display_name=tag&label=%5B%E2%98%B0%5D&labelColor=%238CB4C3&color=%23396175)](https://github.com/geomarker-io/xx_address/releases?q=crime_incidents&expanded=false)
<!-- badges: end -->

The `crime incidents` data package includes the date and street range locations of crime incidents from [PDI (Police Data Initiative) Crime Incidents](https://data.cincinnati-oh.gov/safety/PDI-Police-Data-Initiative-Crime-Incidents/k59e-2pvf) reported between January 1, 2011 and August 3, 2025. Incidents are the records, of reported crimes, collated by an agency for management. Incidents are typically housed in a Records Management System (RMS) that stores agency-wide data about law enforcement operations. This does not include police calls for service, arrest information, final case determination, or any other incident outcome data. 

Crime incident information includes: 
* `incident_no`: incident identifier (one incident can have multiple rows; Each id represents a victim of a crime.)
* `date_time`: the estimated date/time of the start of the crime, filtered to included crime incidents that occurred on or after January 1, 2011
* `hate_bias`: If it is deemed a hate crime, this field will indicate what group the hate crime was aimed at.
* `address_x`: the administratively masked location of the incident
* `lon_jittered` and `lat_jittered`: randomly skewed coordinates (represent the same block area, but not the exact location, of the incident)
* `category`: based on the reported offense; one of `property` (e.g., burglary, larceny, motor vehicle theft, arson), `violent` (e.g., homicide, assault, rape, robbery, domestic violence), or `other` (e.g., missing/unknown, fraud, identify theft, consensual crime)
* `xx_address`: `address_x` with `XX` replaced with `50` to estimate the middle of the street block
* `row_id`: unique row identifier
* `addr_string`: the name of the matched TIGER street
* `ZIP`: zipcode that contains the matched TIGER street
* `addr_street`: addr_street components (see geomarker.io/addr)
* `FROMHN` and `TOHN`: the minimum and maximum building numbers for the geocoded street range
* `s2_geography`: the sfc geometry for the geocoded TIGER street range



