# xx_address

This repository contains these data packages (and source code used to create them): 

<!-- badges: start -->
[![latest github release for crime_incidents dpkg](https://img.shields.io/github/v/release/geomarker-io/xx_address?sort=date&filter=crime_incidents-*&display_name=tag&label=%5B%E2%98%B0%5D&labelColor=%238CB4C3&color=%23396175)](https://github.com/geomarker-io/xx_address/releases?q=crime_incidents&expanded=false)
[![latest github release for shotspotter dpkg](https://img.shields.io/github/v/release/geomarker-io/xx_address?sort=date&filter=shotspotter-*&display_name=tag&label=%5B%E2%98%B0%5D&labelColor=%238CB4C3&color=%23396175)](https://github.com/geomarker-io/xx_address/releases?q=shotspotter&expanded=false)
<!-- badges: end -->

Click the links  to be taken to the most recent release version of each data package and download the parquet data files and README.  Alternatively, import parquet data packages directly with the [dpkg](https://github.com/cole-brokamp/dpkg) R package.

## Administrative Masking

The city of Cincinnati provides publicly available data associated with events reported at the household-level. However, to maintain the privacy of inviduals and households, the addresses are adminstratively masked, meaning the public data reports a street range, rather than an exact house (e.g., 12XX Main Street represents all houses numbered between 1200 and 1299 on Main Street.)

## Matching Street Ranges

The `address_x` provided by the city is converted to possible street range lines from the census bureau using text matching for street names and comparison of street number ranges. It is possible for an `address_x` range to have more than one intersection census street range file, which are unionized to one street range geometry. 

Below is a map of the total number of crime incidents and shotspotter reports for each street range approximation.

![crime_incident_map](https://user-images.githubusercontent.com/104022087/214891725-38ae46aa-3872-485a-bc3f-d6d916d19ad9.svg)

### References

Helderop E, Nelson JR, Grubesic TH. ‘Unmasking’ masked address data: A medoid geocoding solution. MethodsX. 2023;10:102090. doi:10.1016/j.mex.2023.102090
