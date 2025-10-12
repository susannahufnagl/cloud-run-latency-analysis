package main

import (
	"context"
	"encoding/json"
	"errors"
	// "fmt"
	// "io"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
	"sync/atomic"
	"sync"
	"cloud.google.com/go/pubsub"
	"google.golang.org/api/option"
	// "cloud.google.com/go/storage"
)

// type resp struct {
// 	Mode       string   `json:"mode,omitempty"`
//     Op         string   `json:"op"`
//     LatencyMs  *float64 `json:"latency_ms"`   
//     ColdStart  bool     `json:"cold_start"`
//     Error      string   `json:"error,omitempty"`
// }


func mustEnv(k string) string {
	v := os.Getenv(k)
	if v == "" {
		log.Fatalf("missing env %s", k)
	}
	return v
}
func envOr(k, d string) string {
	v := os.Getenv(k)
	if v == "" {
		return d
	}
	return v
}


var sem chan struct{}
var coldFlag uint32 = 1
var initOnce sync.Once
var initOK bool

func isColdStart() bool { return atomic.SwapUint32(&coldFlag, 0) == 1 }

func limiter(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		sem <- struct{}{}
		defer func() { <-sem }()
		h(w, r)
	}
}
// type deps struct {
// 	// bucket *storage.BucketHandle
// 	topic  *pubsub.Topic
// }
// func makeDeps(ctx context.Context) (*deps, error) {
//     project := projectFromEnv()
//     topicID := mustEnv("TOPIC_ID")

//     pub, err := pubsub.NewClient(ctx, project)
//     if err != nil { return nil, fmt.Errorf("pubsub client: %w", err) }

//     topic := pub.Topic(topicID)
//     topic.PublishSettings = pubsub.PublishSettings{
//         CountThreshold: 1,
//         ByteThreshold:  1024,
//         DelayThreshold: 0,
//         NumGoroutines:  1,
//     }
//     return &deps{topic: topic}, nil
// }

//

var (
    pubClient    *pubsub.Client
    topicNoBatch *pubsub.Topic
    topicBatch   *pubsub.Topic
)

func projectFromEnv() string {
    if p := os.Getenv("GCP_PROJECT"); p != "" { return p }
    return os.Getenv("GOOGLE_CLOUD_PROJECT")
}


func initPublisher(ctx context.Context) bool {
    project := projectFromEnv()
    topicID := mustEnv("TOPIC_ID")
	opts := []option.ClientOption{}
    if ep := os.Getenv("PUBSUB_ENDPOINT"); ep != "" {
        opts = append(opts, option.WithEndpoint(ep))
    }
    c, err := pubsub.NewClient(ctx, project, opts...)
    if err != nil {
        log.Printf("[initPublisher] pubsub client: %v", err)
        return false
    }
    nb := c.Topic(topicID)
    nb.PublishSettings = pubsub.PublishSettings{
        CountThreshold: 1, ByteThreshold: 1024, DelayThreshold: 0, NumGoroutines: 1,
    }
    b := c.Topic(topicID)
    b.PublishSettings = pubsub.PublishSettings{
        CountThreshold: 100, ByteThreshold: 100 * 1024, DelayThreshold: 5 * time.Millisecond, NumGoroutines: 4,
    }
    pubClient, topicNoBatch, topicBatch = c, nb, b
    return true
}

func ensurePublisher(ctx context.Context) bool {
    initOnce.Do(func() { initOK = initPublisher(ctx) })
    return initOK
}

// func writeJSON(w http.ResponseWriter, op string, d time.Duration, n int64, err error) {
// 	ms := float64(time.Since(start).Microseconds()) / 1000.0
// 	w.Header().Set("Content-Type", "application/json")
// 	json.NewEncoder(w).Encode(map[string]any{
// 		"op":          "pubsub_publish",
// 		"duration_ms": ms,
// 		"cold_start":  cold,                 // siehe unten
// 		"error":       func() any { if err != nil { return err.Error() }; return nil }(),
// 	})
	
// 	w.Header().Set("X-Op-Latency-Ms", fmt.Sprintf("%.3f", ms))
// 	w.Header().Set("Content-Type", "application/json")
// 	out := resp{Op: op, DurationMs: ms, Bytes: n}
// 	if err != nil {
// 		out.Error = err.Error()
// 	}
// 	_ = json.NewEncoder(w).Encode(out)
// }





// Handler GCS -
// func handleGCSRead(d *deps) http.HandlerFunc {
// 	return limiter(func(w http.ResponseWriter, r *http.Request) {
// 		object := mustEnv("OBJECT_NAME")
// 		cctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
// 		defer cancel()

// 		start := time.Now()
// 		rc, err := d.bucket.Object(object).NewReader(cctx)
// 		if err != nil {
// 			writeJSON(w, "gcs_read", time.Since(start), 0, err)
// 			return
// 		}
// 		defer rc.Close()

// 		n, err := io.Copy(io.Discard, rc)
// 		if err != nil {
// 			writeJSON(w, "gcs_read", time.Since(start), n, err)
// 			return
// 		}

// 		writeJSON(w, "gcs_read", time.Since(start), n, nil)
// 	})
// }


func liveness(w http.ResponseWriter, _ *http.Request) {
    w.WriteHeader(http.StatusOK)
    _, _ = w.Write([]byte("ok"))
}
func readiness(w http.ResponseWriter, r *http.Request) {
	if pubClient != nil && topicNoBatch != nil && topicBatch != nil {
        w.WriteHeader(http.StatusOK); _, _ = w.Write([]byte("ok")); return
    }
    if ensurePublisher(r.Context()) {
        w.WriteHeader(http.StatusOK); _, _ = w.Write([]byte("ok")); return
    }
    http.Error(w, "not ready", http.StatusServiceUnavailable)
}
// func handlePubSub(d *deps) http.HandlerFunc {
//     return limiter(func(w http.ResponseWriter, r *http.Request) {
//         cold := isColdStart()

//         cctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
//         defer cancel()

//         payload := []byte(time.Now().Format(time.RFC3339Nano))
//         start := time.Now()
//         res := d.topic.Publish(cctx, &pubsub.Message{Data: payload})
//         _, err := res.Get(cctx)

//         ms := float64(time.Since(start).Microseconds()) / 1000.0
//         w.Header().Set("Content-Type", "application/json")
//         _ = json.NewEncoder(w).Encode(map[string]any{
//             "op":          "pubsub_publish",
//             "duration_ms": ms,
//             "cold_start":  cold,
//             "error":       func() any { if err != nil { return err.Error() }; return nil }(),
//         })
//     })
// }


func sendPublish(w http.ResponseWriter, r *http.Request, mode string) {
    if pubClient == nil || topicNoBatch == nil || topicBatch == nil {
        if !ensurePublisher(r.Context()) {
            http.Error(w, "pubsub not initialized", http.StatusServiceUnavailable)
            return
        }
    }
    var t *pubsub.Topic
    switch mode {
    case "nobatch": t = topicNoBatch
    case "batch":   t = topicBatch
    default:
        http.Error(w, "invalid mode", http.StatusBadRequest); return
    }
    cold := isColdStart()
    ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
    defer cancel()
    start := time.Now()
    res := t.Publish(ctx, &pubsub.Message{ Data: []byte(time.Now().Format(time.RFC3339Nano)) })
    _, err := res.Get(ctx)
    ms := float64(time.Since(start).Microseconds()) / 1000.0
    // var msPtr *float64
    // if err == nil { msPtr = &ms }
    // w.Header().Set("Content-Type", "application/json")
    // _ = json.NewEncoder(w).Encode(resp{
    //     Mode: mode, Op: "pubsub_publish", LatencyMs: msPtr, ColdStart: cold,
    //     Error: func() string { if err != nil { return err.Error() }; return "" }(),
    // })
	if err != nil {
        // wie Cloud Run: HTTP-Fehler mit Text, kein JSON-Errorobjekt
        http.Error(w, "publish error: "+err.Error(), http.StatusInternalServerError)
        return
    }
    w.Header().Set("Content-Type", "application/json")
    if mode == "nobatch" {
        _ = json.NewEncoder(w).Encode(map[string]any{
            "latency_ms_nobatch": ms,
            "cold_start":         cold,
        })
    } else { // "batch"
        _ = json.NewEncoder(w).Encode(map[string]any{
            "latency_ms_batch": ms,
            "cold_start":       cold,
        })
    }

}

func handleNoBatch(w http.ResponseWriter, r *http.Request) { sendPublish(w, r, "nobatch") }
func handleBatch(w http.ResponseWriter, r *http.Request)   { sendPublish(w, r, "batch") }


func main() {
	cc, _ := strconv.Atoi(envOr("MAX_INFLIGHT", "1"))
	if cc < 1 {
		cc = 1
	}
	sem = make(chan struct{}, cc)
	ensurePublisher(context.Background())
	http.HandleFunc("/", liveness)
	http.HandleFunc("/health", readiness)
	http.HandleFunc("/send/nobatch", limiter(handleNoBatch))
	http.HandleFunc("/send/batch",   limiter(handleBatch))

	log.Printf("listening on :8080 (MAX_INFLIGHT=%d)\n", cc)
	if err := http.ListenAndServe(":8080", nil); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
