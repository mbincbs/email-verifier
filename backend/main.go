package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"time"

	emailverifier "github.com/AfterShip/email-verifier"
)

type JobStatus string

const (
	StatusPending  JobStatus = "pending"
	StatusRunning  JobStatus = "running"
	StatusDone     JobStatus = "done"
	StatusFailed   JobStatus = "failed"
)

type ValidationResult struct {
	Email     string `json:"email"`
	Reachable string `json:"reachable"`
	Error     string `json:"error,omitempty"`
}

type Job struct {
	ID        string              `json:"id"`
	Status    JobStatus           `json:"status"`
	Results   []ValidationResult  `json:"results"`
	CreatedAt time.Time           `json:"created_at"`
	Options   ValidationOptions   `json:"options"`
	Progress  int                 `json:"progress"`
	Total     int                 `json:"total"`
}

type ValidationOptions struct {
	SMTPCheck     bool `json:"smtp_check"`
	GravatarCheck bool `json:"gravatar_check"`
	CatchAllCheck bool `json:"catch_all_check"`
}

var (
	jobs   = make(map[string]*Job)
	jobsMu sync.Mutex
)

func main() {
	os.MkdirAll("results", 0755)
	http.HandleFunc("/api/upload", handleUpload)
	http.HandleFunc("/api/results/", handleResults)
	http.HandleFunc("/api/progress/", handleProgress)
	log.Println("Backend listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handleUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	err := r.ParseMultipartForm(32 << 20) // 32MB
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprintf(w, "Failed to parse form: %v", err)
		return
	}
	file, handler, err := r.FormFile("file")
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprintf(w, "Failed to get file: %v", err)
		return
	}
	defer file.Close()

	options := ValidationOptions{
		SMTPCheck:     r.FormValue("smtp_check") == "true",
		GravatarCheck: r.FormValue("gravatar_check") == "true",
		CatchAllCheck: r.FormValue("catch_all_check") == "true",
	}

	emails, err := parseCSVEmails(file)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprintf(w, "Invalid CSV: %v", err)
		return
	}
	if len(emails) == 0 {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprintf(w, "No emails found in CSV")
		return
	}

	jobID := strconv.FormatInt(time.Now().UnixNano(), 36)
	job := &Job{
		ID:        jobID,
		Status:    StatusPending,
		CreatedAt: time.Now(),
		Options:   options,
		Total:     len(emails),
	}
	jobsMu.Lock()
	jobs[jobID] = job
	jobsMu.Unlock()

	go runValidationJob(job, emails)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"job_id": jobID})
}

func parseCSVEmails(file multipart.File) ([]string, error) {
	r := csv.NewReader(file)
	var emails []string
	for {
		record, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		for _, field := range record {
			if emailverifier.NewVerifier().ParseAddress(field).Valid {
				emails = append(emails, field)
			}
		}
	}
	return emails, nil
}

func runValidationJob(job *Job, emails []string) {
	job.Status = StatusRunning
	results := make([]ValidationResult, len(emails))
	concurrency := 10
	sem := make(chan struct{}, concurrency)
	var wg sync.WaitGroup

	verifier := emailverifier.NewVerifier()
	if job.Options.SMTPCheck {
		verifier.EnableSMTPCheck()
	}
	if job.Options.GravatarCheck {
		verifier.EnableGravatarCheck()
	}
	if !job.Options.CatchAllCheck {
		verifier.DisableCatchAllCheck()
	}

	for i, email := range emails {
		wg.Add(1)
		sem <- struct{}{}
		go func(i int, email string) {
			defer wg.Done()
			res, err := verifier.Verify(email)
			var r ValidationResult
			if err != nil {
				r = ValidationResult{Email: email, Reachable: "error", Error: err.Error()}
			} else {
				r = ValidationResult{Email: email, Reachable: res.Reachable}
			}
			results[i] = r
			jobsMu.Lock()
			job.Progress++
			jobsMu.Unlock()
			<-sem
		}(i, email)
	}
	wg.Wait()
	job.Results = results
	job.Status = StatusDone
}

func handleResults(w http.ResponseWriter, r *http.Request) {
	jobID := filepath.Base(r.URL.Path)
	jobsMu.Lock()
	job, ok := jobs[jobID]
	jobsMu.Unlock()
	if !ok {
		w.WriteHeader(http.StatusNotFound)
		fmt.Fprintf(w, "Job not found")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(job)
}

func handleProgress(w http.ResponseWriter, r *http.Request) {
	jobID := filepath.Base(r.URL.Path)
	jobsMu.Lock()
	job, ok := jobs[jobID]
	jobsMu.Unlock()
	if !ok {
		w.WriteHeader(http.StatusNotFound)
		fmt.Fprintf(w, "Job not found")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"progress": job.Progress,
		"total":    job.Total,
		"status":   job.Status,
	})
}
