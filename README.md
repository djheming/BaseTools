# BaseTools

BaseTools is a collection of foundational Matlab utilities designed for planetary science, geophysical modeling, and general-purpose technical computing. It serves as a low-level dependency for several Hemingway Lab projects.


## Core Functionality

This library provides a suite of static methods organized within the BaseTools class covering:
Coordinate Transformations: Conversions between spherical and Cartesian systems, and geographic mappings (Lat/Lon to Colatitude/Longitude).
Figure & UI Management: Tools for managing complex figure layouts (tileFigures), axes verification, and specialized plotting (arrows, frames, ovals).
Argument Handling: Robust utilities for managing function arguments and mapping variable input arrays to structures (argarray2struct).
Geophysical Utilities: Foundational math for spherical medians, arc lengths, and pressure scaling.
Physical Constants: A consistent set of physical constants (CODATA 2014) used across the Hemingway Lab framework.

### Important Convention Note
Unless otherwise specified in individual function headers, BaseTools assumes a planetary coordinate convention where 
θ (theta) is colatitude (0 at the North Pole, π at the South Pole) and ϕ (phi) is longitude.


## Disclaimer

This code is provided as-is, has been tested only very informally, and may not always behave as intended. It is actively under development and future versions may not be backward compatible. The authors do not guarantee accuracy or robustness.

Maintenance note: This repository is shared in the interest of Open Science. While you are free to use and adapt the code under the MIT License, we do not provide technical support, bug fixes, or guarantee future compatibility.
