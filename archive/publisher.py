# startet flask app , bereitet oub sub_v1.publisherclient vor und initialisiert den client 

import time
from flask import Flask, jsonify
from google.cloud import pubsub_v1
import os

app = Flask(__name__)
publisher = pubsub_v1.PublisherClient()
project_id = os.environ["GCP_PROJECT"]
topic_id = os.environ["TOPIC_ID"]
topic_path = publisher.topic_path(project_id, topic_id)

@app.route("/send")
def send():
    start = time.time()
    future = publisher.publish(topic_path, b"Cloud Run latency test")
    future.result()
    end = time.time()
    latency_ms = (end - start) * 1000
    return jsonify({"latency_ms": round(latency_ms, 2)})
