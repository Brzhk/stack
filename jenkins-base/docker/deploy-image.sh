#!/bin/bash

repository_url=`echo $1 | sed 's~http[s]*://~~g'`
image_name=$2

docker build -t ${image_name} .
docker tag ${image_name}:latest ${repository_url}:latest
docker push ${repository_url}:latest
