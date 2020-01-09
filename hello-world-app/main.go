package main

import (
	"fmt"
	"net/http"
)

const version = "1.0.0"

func main() {
	http.HandleFunc("/", helloServer)
	http.ListenAndServe(":8080", nil)
}

func helloServer(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello, %s! Version: %s", r.URL.Path[1:], version)
}
