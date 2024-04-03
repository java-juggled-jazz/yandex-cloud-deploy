#!/bin/bash

cd apps

docker build --build-arg app-dir=reader --tag cr.yandex/$REGISTRY_ID/reader
docker push cr.yandex/$REGISTRY_ID/reader

docker build --build-arg app-dir=creator --tag cr.yandex/$REGISTRY_ID/creator
docker push cr.yandex/$REGISTRY_ID/creator
