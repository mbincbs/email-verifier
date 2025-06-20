package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	emailverifier "github.com/AfterShip/email-verifier"
)

func main() {
	// Create a new verifier instance
	verifier := emailverifier.NewVerifier()

	// Example email to verify
	email := "test@example.com"

	// Verify the email
	ret, err := verifier.Verify(email)
	if err != nil {
		log.Fatalf("Error verifying email: %v", err)
	}

	// Print the verification result
	result, err := json.MarshalIndent(ret, "", "  ")
	if err != nil {
		log.Fatalf("Error marshaling result: %v", err)
	}

	fmt.Printf("Verification result for %s:\n%s\n", email, string(result))

	// Test the API server if it's running
	testAPIServer()
}

func testAPIServer() {
	fmt.Println("\nTesting API server...")
	
	// Change this to the email you want to test
	email := "test@example.com"
	url := fmt.Sprintf("http://localhost:8081/v1/%s/verification", email)
	
	fmt.Printf("Making request to: %s\n", url)
	resp, err := http.Get(url)
	if err != nil {
		log.Printf("Error calling API server: %v", err)
		return
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("Error reading response body: %v", err)
		return
	}

	fmt.Printf("Response Status: %s\n", resp.Status)
	fmt.Printf("Response Headers: %+v\n", resp.Header)
	fmt.Printf("Response Body: %s\n", string(body))

	// Try to parse the response as JSON
	var result map[string]interface{}
	decoder := json.NewDecoder(bytes.NewReader(body))
	decoder.UseNumber()
	if err := decoder.Decode(&result); err != nil {
		log.Printf("Error decoding API response: %v", err)
		// Try to print the raw response if JSON parsing fails
		fmt.Printf("Raw response: %s\n", string(body))
		return
	}

	// Pretty print the JSON response
	prettyJSON, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		log.Printf("Error formatting JSON: %v", err)
		return
	}

	fmt.Printf("API Server Response for %s:\n%s\n", email, string(prettyJSON))
}
