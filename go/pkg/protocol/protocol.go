package protocol

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path"
	"strings"
	"time"
)

// Entry describes one projected filesystem entry returned by Pharo.
type Entry struct {
	Name     string    `json:"name"`
	Kind     EntryKind `json:"kind"`
	Size     uint64    `json:"size,omitempty"`
	Writable bool      `json:"writable,omitempty"`
}

// EntryKind identifies the filesystem kind of a projected entry.
type EntryKind string

const (
	Directory EntryKind = "directory"
	File      EntryKind = "file"
)

// Diagnostic describes feedback Pharo produced while handling a projection
// operation.
type Diagnostic struct {
	Rule     string `json:"rule,omitempty"`
	Severity string `json:"severity,omitempty"`
	Title    string `json:"title,omitempty"`
	Message  string `json:"message,omitempty"`
}

// WriteResult describes the result of a successful transactional write.
type WriteResult struct {
	Diagnostics []Diagnostic `json:"diagnostics,omitempty"`
}

// Client is the narrow daemon-to-Pharo projection protocol.
type Client interface {
	List(ctx context.Context, path string) ([]Entry, error)
	Stat(ctx context.Context, path string) (Entry, error)
	Read(ctx context.Context, path string) ([]byte, error)
	Write(ctx context.Context, path string, contents []byte) (WriteResult, error)
}

// Error is a projection protocol error.
type Error struct {
	StatusCode int
	Message    string
}

func (e *Error) Error() string {
	if e.Message != "" {
		return e.Message
	}

	return fmt.Sprintf("projection request failed with HTTP status %d", e.StatusCode)
}

// NotFound reports whether an error means the requested path does not exist.
func NotFound(err error) bool {
	protocolError, ok := err.(*Error)
	return ok && protocolError.StatusCode == http.StatusNotFound
}

// ReadOnly reports whether an error means the requested operation attempted to
// write a read-only path.
func ReadOnly(err error) bool {
	protocolError, ok := err.(*Error)
	return ok && protocolError.StatusCode == http.StatusForbidden
}

// HTTPClient calls a Pharo projection backend over JSON HTTP.
type HTTPClient struct {
	baseURL    *url.URL
	httpClient *http.Client
}

// NewHTTPClient answers a projection protocol client using rawBaseURL as the
// endpoint root.
func NewHTTPClient(rawBaseURL string) (*HTTPClient, error) {
	parsedURL, err := url.Parse(rawBaseURL)
	if err != nil {
		return nil, err
	}
	if parsedURL.Scheme == "" || parsedURL.Host == "" {
		return nil, fmt.Errorf("endpoint must be an absolute HTTP URL")
	}

	return &HTTPClient{
		baseURL:    parsedURL,
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}, nil
}

func (c *HTTPClient) List(ctx context.Context, projectionPath string) ([]Entry, error) {
	var response listResponse
	if err := c.post(ctx, "list", pathRequest{Path: projectionPath}, &response); err != nil {
		return nil, err
	}

	return response.Entries, nil
}

func (c *HTTPClient) Stat(ctx context.Context, projectionPath string) (Entry, error) {
	var response statResponse
	if err := c.post(ctx, "stat", pathRequest{Path: projectionPath}, &response); err != nil {
		return Entry{}, err
	}

	return response.Entry, nil
}

func (c *HTTPClient) Read(ctx context.Context, projectionPath string) ([]byte, error) {
	var response readResponse
	if err := c.post(ctx, "read", pathRequest{Path: projectionPath}, &response); err != nil {
		return nil, err
	}

	return []byte(response.Text), nil
}

func (c *HTTPClient) Write(ctx context.Context, projectionPath string, contents []byte) (WriteResult, error) {
	var response writeResponse
	request := writeRequest{
		Path: projectionPath,
		Text: string(contents),
	}
	if err := c.post(ctx, "write", request, &response); err != nil {
		return WriteResult{}, err
	}

	return response.WriteResult, nil
}

func (c *HTTPClient) post(ctx context.Context, operation string, requestBody any, responseBody any) error {
	bodyBytes, err := json.Marshal(requestBody)
	if err != nil {
		return err
	}

	request, err := http.NewRequestWithContext(ctx, http.MethodPost, c.operationURL(operation), bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Accept", "application/json")

	response, err := c.httpClient.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()

	responseBytes, err := io.ReadAll(response.Body)
	if err != nil {
		return err
	}
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
		return &Error{
			StatusCode: response.StatusCode,
			Message:    errorMessageFrom(responseBytes),
		}
	}

	if len(bytes.TrimSpace(responseBytes)) == 0 {
		return nil
	}

	return json.Unmarshal(responseBytes, responseBody)
}

func (c *HTTPClient) operationURL(operation string) string {
	copiedURL := *c.baseURL
	copiedURL.Path = path.Join(c.baseURL.Path, operation)
	return copiedURL.String()
}

func errorMessageFrom(responseBytes []byte) string {
	var response struct {
		Error   string `json:"error"`
		Message string `json:"message"`
	}
	if err := json.Unmarshal(responseBytes, &response); err == nil {
		switch {
		case response.Message != "":
			return response.Message
		case response.Error != "":
			return response.Error
		}
	}

	return strings.TrimSpace(string(responseBytes))
}

type pathRequest struct {
	Path string `json:"path"`
}

type writeRequest struct {
	Path string `json:"path"`
	Text string `json:"text"`
}

type listResponse struct {
	Entries []Entry `json:"entries"`
}

type statResponse struct {
	Entry Entry `json:"entry"`
}

type readResponse struct {
	Text string `json:"text"`
}

type writeResponse struct {
	WriteResult
}
