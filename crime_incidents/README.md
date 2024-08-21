# Crime Incidents

The `crime incidents` data package includes the number and street range locations of crime incidents from [PDI (Police Data Initiative) Crime Incidents](https://data.cincinnati-oh.gov/safety/PDI-Police-Data-Initiative-Crime-Incidents/k59e-2pvf) reported between January 1, 2011 and June 3, 2024. Incidents are the records, of reported crimes, collated by an agency for management. Incidents are typically housed in a Records Management System (RMS) that stores agency-wide data about law enforcement operations. This does not include police calls for service, arrest information, final case determination, or any other incident outcome data. S

Note that in this crime incidents source dataset, each crime incident record is uniquely identified by `INSTANCEID`, but `INCIDENT_NO` may be mapped to multiple `INSTANCEID`. 

A filter is applied to `date-time`, the estimated date/time of the start of the crime, to included crime incidents that occurred on or after January 1, 2011.

Each crime incident is assigned to one of the following categories based on reported `offense`:
* `property` (e.g., burglary, larceny, motor vehicle theft, arson)
* `violent` (e.g., homicide, assault, rape, robbery, domestic violence)
* `other` (e.g., missing/unknown, fraud, identify theft, consensual crime)


