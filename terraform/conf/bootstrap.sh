#!/bin/bash

#
# EMR Bootstrap script for installing GDAL with various image formats.
#

# Get the yum packages required

function process_rpm() {
    wget https://s3.amazonaws.com/azavea-research-public-data/rpms/x86_64/${1}.rpm \
         -O /tmp/${1}.rpm;

    sudo yum localinstall -y /tmp/${1}.rpm;
}

process_rpm proj493-4.9.3-33.x86_64 && \
    process_rpm hdf5-1.8.20-33.x86_64 && \
    process_rpm netcdf-4.5.0-33.x86_64 && \
    process_rpm openjpeg2-2.1.0-7.sdl7.x86_64 && \
    process_rpm openjpeg2-devel-2.1.0-7.sdl7.x86_64 && \
    process_rpm openjpeg2-tools-2.1.0-7.sdl7.x86_64 && \
    process_rpm gdal213-2.1.3-33.x86_64;

#
# Install python packages in both py 2 and 3
# (Hack until I figure out how to consistently make pyspark choose python 3)
#

function pip_install() {
    sudo pip install ${1}
    sudo pip-3.4 install ${1}
}

pip_install boto3
