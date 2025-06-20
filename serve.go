package main

import (
	"fmt"
	"log"
	"net/http"
)

func enableCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func main() {
	// Serve static files from the current directory
	fs := http.FileServer(http.Dir("."))
	http.Handle("/", enableCORS(fs))

	port := "8082"
	fmt.Printf("Starting server on http://localhost:%s\n", port)
	fmt.Printf("Open http://localhost:%s/test_api.html in your browser\n", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
