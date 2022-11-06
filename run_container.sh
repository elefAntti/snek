#!/bin/bash
docker build . -t snek_container
docker run -it --rm \
     --mount type=bind,source="$(pwd)"/snekdata,target=/snekdata \
     snek_container
