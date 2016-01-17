## Optical flow behavioral tracer 
#### last update: 18-05-2014

Based on the optical flow algorithm by Hidetoshi Shimodaira (shimo@is.titech.ac.jp 2010 GPL)
uses the OneEuroFilter for signal smoothing (http://www.lifl.fr/~casiez/1euro/) 
and the cp5 library for GUI elements (http://www.sojamo.de/libraries/controlP5/)

This program provides a solution for quick and dirty tracing of behavioral experiments with mice,
rats, etc. in a wide range of settings and recognized USB Cameras. 

**How to use:**
Application selects camera automatically on start-up. Change camera by hovering over "CAMERAS"
in the top left corner and select the appropiate camera.
To start tracing type in animal or trial name in the field highlighted at start-up
and the time in seconds you want the trace to be performed
IMPORTANT: Do not forget to type in name of current animal / trial!  Repeated names 
in between tracing starts will overwrite previous files!
Click on "Start" to start tracing (yellow bar will appear in top right corner for the length the 
trial. 
"Reset" will delete the traces that appeared since the start of the program. 

Thresholds for flow detection can be set by adjusting sliders on top. Not recommended!

Export: TXT file with 3 comma-separated columns: 
* [0] - time in milliseconds since start of tracing
* [1] - x 
* [2] - y

 Export Structure: 
 * Date/Animal Name/txy_data 'Animal name'.txt
 * Date/Animal Name/trace date 'Animal name'.txt
 Start Export: Camera screenshot (gets refreshed by selecting a different camera option)
