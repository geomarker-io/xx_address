# xx_address

This repository contains data packages: `crime_incidents`, `shotspotter`.

## Administrative Masking

The city of Cincinnati provides publicly available data associated with events reported at the household-level. However, to maintain the privacy of inviduals and households, the addresses are adminstratively masked, meaning the public data reports a street range, rather than an exact house (e.g., 12XX Main Street represents all houses numbered between 1200 and 1299 on Main Street.)

## Matching Street Ranges

The `address_x` provided by the city is converted to possible street range lines from the census bureau using text matching for street names and comparison of street number ranges. It is possible for an `address_x` range to have more than one intersection census street range file, which are unionized to one street range geometry. 

Below is a map of the total number of crime incidents and shotspotter reports for each street range approximation.

![crime_incident_map](https://user-images.githubusercontent.com/104022087/214891725-38ae46aa-3872-485a-bc3f-d6d916d19ad9.svg)