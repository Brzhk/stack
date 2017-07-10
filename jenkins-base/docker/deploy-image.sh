#!/bin/bash

repository_url=`echo $1 | sed 's~http[s]*://~~g'`
image_name=$2


# If the image doesn't exists, we build it and push it to the repository.
if [[ "$(docker images -q ${repository_url} 2> /dev/null)" == "" ]]; then
  cd docker
  docker build -t ${image_name} .
  docker tag ${image_name}:latest ${repository_url}:latest
  docker push ${repository_url}:latest
  cd -
fi
