import os
import time
import threading
from flask import Flask, jsonify



try:
    from google.cloud import pubsub_v1
    HAS_PUBSUB = True
except Exception:
    pubsub_v1 = None
    HAS_PUBSUB = False

app = Flask(__name__)
app.url_map.strict_slashes = False




PROJECT = os.environ.get("GCP_PROJECT") or os.environ.get("GOOGLE_CLOUD_PROJECT")
TOPIC   = os.environ.get("TOPIC_ID")
PORT    = int(os.environ.get("PORT", "8080"))

publisher = None
topic_path = None

_cold_flag = 1
_cold_lock = threading.Lock()




def is_cold_start() -> bool:
    global _cold_flag
    with _cold_lock:
        if _cold_flag == 1:
            _cold_flag= 0 
            return True
        return False

def init_publisher():
    ##Batching AUS (Count=1, Bytes=1, Delay=0) für reproduzierbare Messungen.
    global publisher, topic_path
    if not (HAS_PUBSUB and PROJECT and TOPIC):
        # Hilfreiches Diagnose-Log, wenn eine Voraussetzung fehlt
        print(f"[init_publisher] missing -> HAS_PUBSUB={HAS_PUBSUB} PROJECT={PROJECT} TOPIC={TOPIC}",
              flush=True)
        return False
    batch = pubsub_v1.types.BatchSettings(
        max_messages=1,
        max_bytes=1024,     
        max_latency=0    
    )
    try:
        publisher = pubsub_v1.PublisherClient(batch_settings=batch)
        topic_path = publisher.topic_path(PROJECT, TOPIC)
        print(f"[init_publisher] OK -> {topic_path}", flush=True)
        return True
    except Exception as e:
        print(f"[init_publisher] failed: {e}", flush=True)
        publisher = None
        topic_path = None
        return False


@app.get("/")
def liveness():#prozess läuft 
    
    return "ok", 200

@app.get("/health")
def health():
    print("[HEALTH] handler reached", flush=True)
    return "ok", 200

@app.get("/readyz")
def readyz():
    print("[READYZ] handler reached", flush=True)
    if publisher and topic_path: return "ok", 200
    if init_publisher():return "ok", 200
    return "not ready", 503

@app.get("/send")
def send():
    
    if not (publisher and topic_path):
        if not init_publisher():
            return jsonify(error="Pub/Sub not initialized"), 503
        
    cold = is_cold_start()
    
    t0 = time.perf_counter() #uhr starten 
    fut = publisher.publish(topic_path, b"Cloud Run latency test") # geht in message broker 
    try:
        #blockiert bis brocker ack ack 
       
        fut.result(timeout=30)
    except Exception as e:
        return jsonify(error=f"publish error: {type(e).__name__}: {e}"), 500

    ms = round((time.perf_counter() - t0) * 1000.0, 2) # zeit berechenen darauf
    return jsonify(latency_ms=ms, cold_start = cold), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT)
    
with app.app_context():
    for r in app.url_map.iter_rules():
        codepoints = [hex(ord(c)) for c in r.rule]
        print(f"[route] raw={r.rule!r} codepoints={codepoints}", flush=True)
