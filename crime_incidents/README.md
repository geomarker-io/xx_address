# Crime Incidents

<!-- badges: start -->
[![latest github release for crime_incidents dpkg](https://img.shields.io/github/v/release/geomarker-io/xx_address?sort=date&filter=crime_incidents-*&display_name=tag&label=%5B%E2%98%B0%5D&labelColor=%238CB4C3&color=%23396175)](https://github.com/geomarker-io/xx_address/releases?q=crime_incidents&expanded=false)
<!-- badges: end -->

The `crime incidents` data package includes the date and street range locations of crime incidents from [PDI (Police Data Initiative) Crime Incidents](https://data.cincinnati-oh.gov/safety/PDI-Police-Data-Initiative-Crime-Incidents/k59e-2pvf) reported between January 1, 2011 and June 3, 2024. Incidents are the records, of reported crimes, collated by an agency for management. Incidents are typically housed in a Records Management System (RMS) that stores agency-wide data about law enforcement operations. This does not include police calls for service, arrest information, final case determination, or any other incident outcome data. 

Note that in this crime incidents source dataset, each crime incident record is uniquely identified by `INSTANCEID`, but `INCIDENT_NO` may be mapped to multiple `INSTANCEID`. 

A filter is applied to `date-time`, the estimated date/time of the start of the crime, to included crime incidents that occurred on or after January 1, 2011.

Each crime incident is assigned to one of the following categories based on reported `offense`:
* `property` (e.g., burglary, larceny, motor vehicle theft, arson)
* `violent` (e.g., homicide, assault, rape, robbery, domestic violence)
* `other` (e.g., missing/unknown, fraud, identify theft, consensual crime)


