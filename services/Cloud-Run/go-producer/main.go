package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
	"sync"
	"sync/atomic"
	"cloud.google.com/go/pubsub"
	"google.golang.org/api/option"
)
//schalter einbauen 

var (
	projectID string
	topicID   string
	port      string

	client       *pubsub.Client
	topicBatch   *pubsub.Topic
	topicNoBatch *pubsub.Topic
	coldFlag uint32=1
	initOnce sync.Once
	initOK   bool
)


func isColdStart() bool{
	//liest atomar alten wert von coldFlag und setzt ihn gleichzeitig auf 0 
	return atomic.SwapUint32(&coldFlag, 0) == 1  // wenn der alte wert 1 war(cold start ) bekomme ich true zurück
 
}

func init() {
	projectID = os.Getenv("GCP_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GOOGLE_CLOUD_PROJECT")
	}
	topicID = os.Getenv("TOPIC_ID")

	port = os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
}

//erzeugt client und zwei topic handles (batch/nobatch)
func initPublisher(ctx context.Context) bool {
	if projectID == "" || topicID == "" {
		log.Println("[initPublisher] missing PROJECT or TOPIC")
		return false
	}
	var opts []option.ClientOption
    if ep := os.Getenv("PUBSUB_ENDPOINT"); ep != "" {
        opts = append(opts, option.WithEndpoint(ep))
    }

	c, err := pubsub.NewClient(ctx, projectID, opts...) //c als eigentliches ergebnis und err als fehler
	if err != nil {
		log.Printf("[initPublisher] failed: %v", err)
		return false
	}
	//batching aus
	t1 := c.Topic(topicID)                       //lokales Objekt, repräsentiert topic in meinem Projekt
	t1.PublishSettings = pubsub.PublishSettings{ //jede Nachirhct wird sofort raugseschickt keine bündelung
		CountThreshold: 1,
		ByteThreshold:  1024, // so klein wie möglich
		DelayThreshold: 0,
		NumGoroutines:  1,
	}
	//Batching an dh hier werden die anchrichten erst gesammelt und gemeinsam dann ruasgeschickt
	t2 := c.Topic(topicID)
	t2.PublishSettings = pubsub.PublishSettings{
		CountThreshold: 100,                  //wie viel messagaes gesammmelt
		ByteThreshold:  100 * 1024,           //
		DelayThreshold: 5 * time.Millisecond, //time.milli //wie lange maximal warten
		NumGoroutines:  4,
	}
	client = c
	topicNoBatch = t1
	topicBatch = t2
	return true
}
func ensurePublisher(ctx context.Context) bool {
	initOnce.Do(func() { initOK = initPublisher(ctx) })
	return initOK
}


func liveness(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

func readiness(w http.ResponseWriter, r *http.Request) {
	if client != nil && topicNoBatch != nil && topicBatch != nil {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
		return
	}
	if ensurePublisher(r.Context()) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
		return
	}

	http.Error(w, "not ready", http.StatusServiceUnavailable)
}

func send_batch(w http.ResponseWriter, r *http.Request) {
	cold:= isColdStart()
	// if isColdStart(){
	// 	log.Println("coldstart = true")
	// }
	if client == nil || topicBatch == nil { //&& topicNoBatch == nil {
		if !ensurePublisher(r.Context()) {
			http.Error(w, "Pub/Sub batch not initialized", http.StatusServiceUnavailable)
			return
		}
	}

	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	start := time.Now()
	
	res2 := topicBatch.Publish(ctx, &pubsub.Message{ //zugriff auf oben t topic objekt shcickt nachtih msg raus und ctx muss in go dast überall mitgegegben werden, aussage über
		Data: []byte("Cloud Run batch latency test"), //message
	})

	
	if _, err := res2.Get(ctx); err != nil {
		http.Error(w, "publish error: "+err.Error(), http.StatusInternalServerError)
		return
	}
	ms := float64(time.Since(start).Microseconds()) / 1000.0
	
	w.Header().Set("Content-Type", "application/json")
	_=json.NewEncoder(w).Encode(map[string]any{
		"latency_ms_batch": ms,
		"cold_start": cold,
	})
}

func send_nobatch(w http.ResponseWriter, r *http.Request) {
	// if isColdStart(){
	// 	log.Println("coldstart = true")
	// }
	cold:= isColdStart()
	if client == nil || topicNoBatch == nil { //&& topicBatch == nil {
		if !ensurePublisher(r.Context()) {
			http.Error(w, "Pub/Sub no batch not initialized", http.StatusServiceUnavailable)
			return
		}
	}

	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	start := time.Now()
	res1 := topicNoBatch.Publish(ctx, &pubsub.Message{ //zugriff auf oben t topic objekt shcickt nachtih msg raus und ctx muss in go dast überall mitgegegben werden, aussage über
		Data: []byte("Cloud Run no batch latency test"), //message
	})
	// res2 := topicBatch.Publish(ctx, &pubsub.Message{ //zugriff auf oben t topic objekt shcickt nachtih msg raus und ctx muss in go dast überall mitgegegben werden, aussage über
	// 	Data: []byte("Cloud Run latency test"),//message
	// })

	if _, err := res1.Get(ctx); err != nil {
		http.Error(w, "publish error: "+err.Error(), http.StatusInternalServerError)
		return
	}
	
	ms := float64(time.Since(start).Microseconds()) / 1000.0
	
	w.Header().Set("Content-Type", "application/json")
	_=json.NewEncoder(w).Encode(map[string]any{
		"latency_ms_nobatch": ms,
		"cold_start": cold,
	})
}

func main() {
	// Früh  bauen
	ensurePublisher(context.Background())

	http.HandleFunc("/", liveness)
	http.HandleFunc("/health", readiness)
	http.HandleFunc("/send/nobatch", send_nobatch)
	http.HandleFunc("/send/batch", send_batch)

	log.Printf("listening on :%s", port)
	log.Fatal(http.ListenAndServe("0.0.0.0:"+port, nil))
}
