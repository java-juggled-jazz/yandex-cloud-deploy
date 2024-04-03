import os
from fastapi import FastAPI
import psycopg2

CLUSTER_ID = os.environ['CLUSTER_ID']
DB_PORT = os.environ['DB_PORT']
DB_NAME = os.environ['DB_NAME']
DB_USERNAME = os.environ['DB_USERNAME']
DB_PASSWORD = os.environ['DB_PASSWORD']

app = FastAPI()

@app.post("/", status_code=200)
def create(data_post = Body()):
    conn = psycopg2.connect(host=f"c-{CLUSTER_ID}.rw.mdb.yandexcloud.net", port=DB_PORT, dbname=DB_NAME, user=DB_USERNAME, password=DB_PASSWORD, target_session_attrs="read-write", sslmode="verify-full", sslrootcert="/etc/ssl/.postgres/root.crt")

    ID = data_post["ID"]

    q = conn.cursor()
    q.execute('SELECT message FROM messages WHERE id = %s', ID)
    MESSAGE = q.fetchone()

    conn.close()
    return {"message": MESSAGE}

