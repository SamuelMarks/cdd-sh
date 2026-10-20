// Package gojqcli implements the internal gojq command-line interface and JSON streaming utilities.
package gojqcli

import (
	"encoding/json"
	"io"
)

// jsonStream maintains state for streaming JSON token parsing (`jq --stream`).
type jsonStream struct {
	dec    *json.Decoder
	path   []any
	states []int
}

// newJSONStream initializes a new jsonStream wrapping the given json.Decoder.
// Parameters:
//   - dec: The underlying JSON token decoder.
//
// Returns a pointer to the initialized jsonStream.
func newJSONStream(dec *json.Decoder) *jsonStream {
	return &jsonStream{dec: dec, states: []int{jsonStateTopValue}, path: []any{}}
}

const (
	jsonStateTopValue = iota
	jsonStateArrayStart
	jsonStateArrayValue
	jsonStateArrayEnd
	jsonStateArrayEmptyEnd
	jsonStateObjectStart
	jsonStateObjectKey
	jsonStateObjectValue
	jsonStateObjectEnd
	jsonStateObjectEmptyEnd
)

// next advances the JSON stream and returns the next path-value tuple or path-end tuple.
// Parameters:
//   - none
//
// Returns the stream tuple (`[]any`) and any decoding error.
func (s *jsonStream) next() (any, error) {
	switch s.states[len(s.states)-1] {
	case jsonStateArrayEnd, jsonStateObjectEnd:
		s.path = s.path[:len(s.path)-1]
		fallthrough
	case jsonStateArrayEmptyEnd, jsonStateObjectEmptyEnd:
		s.states = s.states[:len(s.states)-1]
	}
	if s.dec.More() {
		switch s.states[len(s.states)-1] {
		case jsonStateArrayValue:
			s.path[len(s.path)-1] = s.path[len(s.path)-1].(int) + 1
		case jsonStateObjectValue:
			s.path = s.path[:len(s.path)-1]
		}
	}
	for {
		token, err := s.dec.Token()
		if err != nil {
			if err == io.EOF && s.states[len(s.states)-1] != jsonStateTopValue {
				err = io.ErrUnexpectedEOF
			}
			return nil, err
		}
		if d, ok := token.(json.Delim); ok {
			switch d {
			case '[', '{':
				switch s.states[len(s.states)-1] {
				case jsonStateArrayStart:
					s.states[len(s.states)-1] = jsonStateArrayValue
				case jsonStateObjectKey:
					s.states[len(s.states)-1] = jsonStateObjectValue
				}
				if d == '[' {
					s.states = append(s.states, jsonStateArrayStart)
					s.path = append(s.path, 0)
				} else {
					s.states = append(s.states, jsonStateObjectStart)
				}
			case ']':
				if s.states[len(s.states)-1] == jsonStateArrayStart {
					s.states[len(s.states)-1] = jsonStateArrayEmptyEnd
					s.path = s.path[:len(s.path)-1]
					return []any{s.copyPath(), []any{}}, nil
				}
				s.states[len(s.states)-1] = jsonStateArrayEnd
				return []any{s.copyPath()}, nil
			case '}':
				if s.states[len(s.states)-1] == jsonStateObjectStart {
					s.states[len(s.states)-1] = jsonStateObjectEmptyEnd
					return []any{s.copyPath(), map[string]any{}}, nil
				}
				s.states[len(s.states)-1] = jsonStateObjectEnd
				return []any{s.copyPath()}, nil
			}
		} else {
			switch s.states[len(s.states)-1] {
			case jsonStateArrayStart:
				s.states[len(s.states)-1] = jsonStateArrayValue
				fallthrough
			case jsonStateArrayValue:
				return []any{s.copyPath(), token}, nil
			case jsonStateObjectStart, jsonStateObjectValue:
				s.states[len(s.states)-1] = jsonStateObjectKey
				s.path = append(s.path, token)
			case jsonStateObjectKey:
				s.states[len(s.states)-1] = jsonStateObjectValue
				return []any{s.copyPath(), token}, nil
			default:
				s.states[len(s.states)-1] = jsonStateTopValue
				return []any{s.copyPath(), token}, nil
			}
		}
	}
}

// copyPath returns a shallow copy of the current JSON path slice.
// Parameters:
//   - none
//
// Returns a copied slice of path elements.
func (s *jsonStream) copyPath() []any {
	path := make([]any, len(s.path))
	copy(path, s.path)
	return path
}
