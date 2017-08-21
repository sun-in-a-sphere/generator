

# **The Sun in A Sphere**



Skript for downloading 360° images from https://stereo-ssc.nascom.nasa.gov/browse_sphere/

and process them to a movie and project to a sphere

The processed images are meant to be used and are tested with a laserbeamer and  a 180° fish eye lens.

For more information and a DIY guide visit  https://sun-in-a-sphere.github.io

Configuration file sun-in-a-sphere.conf contains various adjustable settings.

​    

Authors: Lukas Musy & Mischa Nüesch

Organization: FHNW



### Installation Guide



Prequesites:

- Imagemagick (tested on version 7.06)

- Mplayer (tested on version 4.2.1)

- GNU Parallel

Linux comes preinstalled with these. On multi processor systems it is recommended to make sure you have imagemagick installed with support for OpenMP and OpenCL. Check with `convert -v | grep OpenMP`

On MacOS to install the dependencies install homebrew https://brew.sh/, open a terminal and type

`brew install imagemagick  --with-openmp –with-opencl mplayer parallel`



#### Linux

On multi processor systems it is recommended to make sure you have imagemagick installed with support for OpenMP and OpenCL.

`

1. Get the package at https://github.com/sun-in-a-sphere/generator/releases/tag/1.0.1

2. Open a shell and type:

   ``apt install ./ sun-in-a-sphere.deb``



2. Adjust the configuration file *sun-in-a-sphere.conf*  to taste. 

   ​

3. Run the script with: (conf file needs to be in current folder)

    `./sun-in-a-sphere.sh`

   ​




  
    
    
#### MacOS

1. Get the Package at https://github.com/sun-in-a-sphere/generator/releases/tag/1.0 

   ​

2. Adjust the configuration file *sun-in-a-sphere.conf*  to taste. 

   ​

3. For easy install, double click  `sun-in-a-sphere.command`.

   ​

   Or open a terminal and type:

   `chmod u+x ./sun-in-a-sphere.sh`

   `./sun-in-a-sphere.sh`
