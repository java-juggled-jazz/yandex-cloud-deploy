#!/bin/bash

source .env
cd apps

docker build . --tag cr.yandex/$REGISTRY_ID/reader
docker push cr.yandex/$REGISTRY_ID/reader

docker build . --tag cr.yandex/$REGISTRY_ID/creator
docker push cr.yandex/$REGISTRY_ID/creator
