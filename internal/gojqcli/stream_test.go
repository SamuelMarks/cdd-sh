package gojqcli

import (
	"bytes"
	"encoding/json"
	"reflect"
	"testing"
)

func TestJSONStream(t *testing.T) {
	tests := []struct {
		input string
		want  [][]any
	}{
		{
			`[1, 2, 3]`,
			[][]any{
				{[]any{0}, 1.0},
				{[]any{1}, 2.0},
				{[]any{2}, 3.0},
				{[]any{2}},
			},
		},
		{
			`{"a": 1, "b": {"c": 2}}`,
			[][]any{
				{[]any{"a"}, 1.0},
				{[]any{"b", "c"}, 2.0},
				{[]any{"b", "c"}},
				{[]any{"b"}},
			},
		},
		{
			`[]`,
			[][]any{
				{[]any{}, []any{}},
			},
		},
		{
			`{}`,
			[][]any{
				{[]any{}, map[string]any{}},
			},
		},
		{
			`[{"a": []}, {}]`,
			[][]any{
				{[]any{0, "a"}, []any{}},
				{[]any{0, "a"}},
				{[]any{1}, map[string]any{}},
				{[]any{1}},
			},
		},
	}

	for _, tt := range tests {
		dec := json.NewDecoder(bytes.NewReader([]byte(tt.input)))

		s := newJSONStream(dec)
		var got [][]any
		for {
			v, err := s.next()
			if err != nil {
				break
			}
			got = append(got, v.([]any))
		}

		if !reflect.DeepEqual(got, tt.want) {
			t.Errorf("for input %q,\nwant: %#v\ngot:  %#v", tt.input, tt.want, got)
		}
	}
}
