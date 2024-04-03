FROM public.ecr.aws/docker/library/python:slim-bullseye
WORKDIR /app
RUN apt-get update && \
    apt-get install wget postgresql-client --yes && \
    mkdir --parents /etc/ssl/.postgresql && \
    wget "https://storage.yandexcloud.net/cloud-certs/CA.pem" \
         --output-document /etc/ssl/.postgresql/root.crt && \
    chmod 0600 /etc/ssl/.postgresql/root.crt
COPY . /app
RUN pip install -r requirements.txt
ENTRYPOINT ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]
