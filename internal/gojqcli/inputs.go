// Package gojqcli implements input readers and iterators for JSON, raw text, and slurped files.
package gojqcli

import (
	"bufio"
	"bytes"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/itchyny/gojq"
)

// inputReader wraps an io.Reader to preserve read bytes or seek offsets for syntax error reporting.
type inputReader struct {
	io.Reader
	rs  io.ReadSeeker
	buf *bytes.Buffer
}

// newInputReader creates an inputReader wrapping r, using io.ReadSeeker directly if supported or TeeReader otherwise.
// Parameters:
//   - r: The underlying input stream.
//
// Returns a pointer to the initialized inputReader.
func newInputReader(r io.Reader) *inputReader {
	if r, ok := r.(io.ReadSeeker); ok {
		if _, err := r.Seek(0, io.SeekCurrent); err == nil {
			return &inputReader{r, r, nil}
		}
	}
	var buf bytes.Buffer // do not use strings.Builder because we need to Reset
	return &inputReader{io.TeeReader(r, &buf), nil, &buf}
}

// getContents returns the buffered or seeked source text window around the given byte offset and updates line count.
// Parameters:
//   - offset: Pointer to the byte offset of the parse error.
//   - line: Pointer to the accumulated line number.
//
// Returns the relevant source text slice as a string.
func (ir *inputReader) getContents(offset *int64, line *int) string {
	if buf := ir.buf; buf != nil {
		return buf.String()
	}
	if current, err := ir.rs.Seek(0, io.SeekCurrent); err == nil {
		defer ir.rs.Seek(current, io.SeekStart)
	}
	_, _ = ir.rs.Seek(0, io.SeekStart)
	const bufSize = 16 * 1024
	var buf bytes.Buffer // do not use strings.Builder because we need to Reset
	for offset != nil && *offset > bufSize*3/4 {
		n, err := io.Copy(&buf,
			io.LimitReader(ir.rs, min(bufSize, *offset-bufSize/4)))
		*offset -= n
		*line += bytes.Count(buf.Bytes(), []byte{'\n'})
		buf.Reset()
		if err != nil || n == 0 {
			break
		}
	}
	_, _ = io.Copy(&buf, io.LimitReader(ir.rs, bufSize))
	return buf.String()
}

// inputIter extends gojq.Iter with io.Closer and source file name reporting.
type inputIter interface {
	gojq.Iter
	io.Closer
	Name() string
}

// jsonInputIter decodes sequential JSON values from an inputReader.
type jsonInputIter struct {
	next   func() (any, error)
	ir     *inputReader
	fname  string
	offset int64
	line   int
	err    error
}

// newJSONInputIter creates an inputIter that decodes standard JSON values from r.
// Parameters:
//   - r: The input stream to decode.
//   - fname: The display name or file path of the input source.
//
// Returns the initialized inputIter.
func newJSONInputIter(r io.Reader, fname string) inputIter {
	ir := newInputReader(r)
	dec := json.NewDecoder(ir)
	dec.UseNumber()
	next := func() (v any, err error) { err = dec.Decode(&v); return }
	return &jsonInputIter{next: next, ir: ir, fname: fname}
}

// Next decodes and returns the next JSON value or a jsonParseError on invalid syntax.
// Parameters:
//   - none
//
// Returns the decoded value (or error) and true if a value/error was produced.
func (i *jsonInputIter) Next() (any, bool) {
	if i.err != nil {
		return nil, false
	}
	v, err := i.next()
	if err != nil {
		if err == io.EOF {
			i.err = err
			return nil, false
		}
		var offset *int64
		var line *int
		if e, ok := err.(*json.SyntaxError); ok {
			e.Offset -= i.offset
			offset, line = &e.Offset, &i.line
		} else if err == io.ErrUnexpectedEOF && i.ir.rs != nil {
			if pos, err := i.ir.rs.Seek(0, io.SeekEnd); err == nil {
				offset, line = &pos, &i.line
			}
		}
		i.err = &jsonParseError{i.fname, i.ir.getContents(offset, line), i.line, err}
		return i.err, true
	}
	if buf := i.ir.buf; buf != nil && buf.Len() >= 16*1024 {
		i.offset += int64(buf.Len())
		i.line += bytes.Count(buf.Bytes(), []byte{'\n'})
		buf.Reset()
	}
	return v, true
}

// Close marks the iterator as exhausted and releases resources.
// Parameters:
//   - none
//
// Returns nil.
func (i *jsonInputIter) Close() error {
	i.err = io.EOF
	return nil
}

// Name returns the source file name associated with this iterator.
// Parameters:
//   - none
//
// Returns the source file name string.
func (i *jsonInputIter) Name() string {
	return i.fname
}

// nullInputIter yields a single nil value (`jq -n`).
type nullInputIter struct {
	err error
}

// newNullInputIter creates an inputIter that yields a single null value.
// Parameters:
//   - none
//
// Returns the initialized nullInputIter.
func newNullInputIter() inputIter {
	return &nullInputIter{}
}

// Next yields nil on the first call and (nil, false) on subsequent calls.
// Parameters:
//   - none
//
// Returns nil and true on first invocation, then nil and false.
func (i *nullInputIter) Next() (any, bool) {
	if i.err != nil {
		return nil, false
	}
	i.err = io.EOF
	return nil, true
}

// Close marks the nullInputIter as finished.
// Parameters:
//   - none
//
// Returns nil.
func (i *nullInputIter) Close() error {
	i.err = io.EOF
	return nil
}

// Name returns an empty string for null input.
// Parameters:
//   - none
//
// Returns an empty string.
func (*nullInputIter) Name() string {
	return ""
}

// filesInputIter iterates sequentially across multiple named files or standard input.
type filesInputIter struct {
	newIter  func(io.Reader, string) inputIter
	fnames   []string
	stdin    io.Reader
	iter     inputIter
	file     io.Reader
	err      error
	resolver func(string) string
}

// newFilesInputIter creates an inputIter that opens and iterates through each file in fnames using default path resolution.
// Parameters:
//   - newIter: Factory function to construct an inputIter for each opened file.
//   - fnames: Slice of file paths (or "-" for stdin).
//   - stdin: Standard input reader used when fname is "-".
//
// Returns the initialized filesInputIter.
func newFilesInputIter(
	newIter func(io.Reader, string) inputIter, fnames []string, stdin io.Reader,
) inputIter {
	return newFilesInputIterWithResolver(newIter, fnames, stdin, resolveJqPath)
}

// newFilesInputIterWithResolver creates an inputIter that opens and iterates through each file in fnames using an explicit path resolver.
// Parameters:
//   - newIter: Factory function to construct an inputIter for each opened file.
//   - fnames: Slice of file paths (or "-" for stdin).
//   - stdin: Standard input reader used when fname is "-".
//   - resolver: Scoped path resolution function for relative file paths.
//
// Returns the initialized filesInputIter.
func newFilesInputIterWithResolver(
	newIter func(io.Reader, string) inputIter, fnames []string, stdin io.Reader, resolver func(string) string,
) inputIter {
	return &filesInputIter{newIter: newIter, fnames: fnames, stdin: stdin, resolver: resolver}
}

// Next advances to the next value in the current file or opens the next file in fnames.
// Parameters:
//   - none
//
// Returns the next value and true if available.
func (i *filesInputIter) Next() (any, bool) {
	if i.err != nil {
		return nil, false
	}
	for {
		if i.file == nil {
			if len(i.fnames) == 0 {
				i.err = io.EOF
				if i.iter != nil {
					i.iter.Close()
					i.iter = nil
				}
				return nil, false
			}
			fname := i.fnames[0]
			i.fnames = i.fnames[1:]
			if fname == "-" && i.stdin != nil {
				i.file, fname = i.stdin, "<stdin>"
			} else {
				var file io.ReadCloser
				var err error
				if EmbeddedFS != nil {
					cleanName := filepath.Clean(fname)
					for len(cleanName) > 0 && cleanName[0] == '/' {
						cleanName = cleanName[1:]
					}
					f, errFs := EmbeddedFS.Open(cleanName)
					if errFs == nil {
						file = f
						err = nil
					}
				}
				if file == nil {
					resolved := fname
					if i.resolver != nil {
						resolved = i.resolver(fname)
					}
					file, err = os.Open(resolved)
				}
				if err != nil {
					return err, true
				}
				i.file = file
			}
			if i.iter != nil {
				i.iter.Close()
			}
			i.iter = i.newIter(i.file, fname)
		}
		if v, ok := i.iter.Next(); ok {
			return v, ok
		}
		if r, ok := i.file.(io.Closer); ok && i.file != i.stdin {
			r.Close()
		}
		i.file = nil
	}
}

// Close closes the currently open file handle if any.
// Parameters:
//   - none
//
// Returns nil.
func (i *filesInputIter) Close() error {
	if i.file != nil {
		if r, ok := i.file.(io.Closer); ok && i.file != i.stdin {
			r.Close()
		}
		i.file = nil
		i.err = io.EOF
	}
	return nil
}

// Name returns the active file's display name.
// Parameters:
//   - none
//
// Returns the active file name string.
func (i *filesInputIter) Name() string {
	if i.iter != nil {
		return i.iter.Name()
	}
	return ""
}

// rawInputIter reads input line-by-line as raw strings (`jq -R`).
type rawInputIter struct {
	r     *bufio.Reader
	fname string
	err   error
}

// newRawInputIter creates an inputIter that reads raw lines from r.
// Parameters:
//   - r: The input stream to read.
//   - fname: The display name of the input source.
//
// Returns the initialized rawInputIter.
func newRawInputIter(r io.Reader, fname string) inputIter {
	return &rawInputIter{r: bufio.NewReader(r), fname: fname}
}

// Next reads and returns the next line with any trailing newline removed.
// Parameters:
//   - none
//
// Returns the trimmed line string and true if available.
func (i *rawInputIter) Next() (any, bool) {
	if i.err != nil {
		return nil, false
	}
	line, err := i.r.ReadString('\n')
	if err != nil {
		i.err = err
		if err != io.EOF {
			return err, true
		}
		if line == "" {
			return nil, false
		}
	}
	return strings.TrimSuffix(line, "\n"), true
}

// Close marks the rawInputIter as exhausted.
// Parameters:
//   - none
//
// Returns nil.
func (i *rawInputIter) Close() error {
	i.err = io.EOF
	return nil
}

// Name returns the source file name for this rawInputIter.
// Parameters:
//   - none
//
// Returns the source file name string.
func (i *rawInputIter) Name() string {
	return i.fname
}

// slurpInputIter collects all values from an underlying inputIter into a single slice (`jq -s`).
type slurpInputIter struct {
	iter inputIter
	err  error
}

// newSlurpInputIter wraps iter to slurp all yielded items into a single array.
// Parameters:
//   - iter: The underlying inputIter to slurp.
//
// Returns the initialized slurpInputIter.
func newSlurpInputIter(iter inputIter) inputIter {
	return &slurpInputIter{iter: iter}
}

// Next consumes all items from the underlying iterator and returns them as a single []any slice.
// Parameters:
//   - none
//
// Returns the slurped slice and true on first call.
func (i *slurpInputIter) Next() (any, bool) {
	if i.err != nil {
		return nil, false
	}
	var vs []any
	var v any
	var ok bool
	for {
		v, ok = i.iter.Next()
		if !ok {
			i.err = io.EOF
			return vs, true
		}
		if i.err, ok = v.(error); ok {
			return i.err, true
		}
		vs = append(vs, v)
	}
}

// Close closes the underlying iterator and marks slurpInputIter as finished.
// Parameters:
//   - none
//
// Returns nil.
func (i *slurpInputIter) Close() error {
	if i.iter != nil {
		i.iter.Close()
		i.iter = nil
		i.err = io.EOF
	}
	return nil
}

// Name returns the source name from the underlying iterator.
// Parameters:
//   - none
//
// Returns the source file name string.
func (i *slurpInputIter) Name() string {
	return i.iter.Name()
}

// readAllIter reads the entire content of an io.Reader as a single raw string (`jq -Rs`).
type readAllIter struct {
	r     io.Reader
	fname string
	err   error
}

// newReadAllIter creates an inputIter that reads the entire stream r into a single string.
// Parameters:
//   - r: The input stream to read completely.
//   - fname: The display name of the input source.
//
// Returns the initialized readAllIter.
func newReadAllIter(r io.Reader, fname string) inputIter {
	return &readAllIter{r: r, fname: fname}
}

// Next reads all bytes from r and returns them as a single string.
// Parameters:
//   - none
//
// Returns the full content string and true on first call.
func (i *readAllIter) Next() (any, bool) {
	if i.err != nil {
		return nil, false
	}
	i.err = io.EOF
	cnt, err := io.ReadAll(i.r)
	if err != nil {
		return err, true
	}
	return string(cnt), true
}

// Close marks the readAllIter as exhausted.
// Parameters:
//   - none
//
// Returns nil.
func (i *readAllIter) Close() error {
	i.err = io.EOF
	return nil
}

// Name returns the source name for this readAllIter.
// Parameters:
//   - none
//
// Returns the source file name string.
func (i *readAllIter) Name() string {
	return i.fname
}

// slurpRawInputIter concatenates multiple raw string inputs into a single string (`jq -Rs` across files).
type slurpRawInputIter struct {
	iter inputIter
	err  error
}

// newSlurpRawInputIter wraps iter to concatenate all yielded raw strings into one string.
// Parameters:
//   - iter: The underlying raw input iterator.
//
// Returns the initialized slurpRawInputIter.
func newSlurpRawInputIter(iter inputIter) inputIter {
	return &slurpRawInputIter{iter: iter}
}

// Next reads all string values from the underlying iterator and joins them into a single string.
// Parameters:
//   - none
//
// Returns the concatenated string and true on first call.
func (i *slurpRawInputIter) Next() (any, bool) {
	if i.err != nil {
		return nil, false
	}
	var vs []string
	var v any
	var ok bool
	for {
		v, ok = i.iter.Next()
		if !ok {
			i.err = io.EOF
			return strings.Join(vs, ""), true
		}
		if i.err, ok = v.(error); ok {
			return i.err, true
		}
		vs = append(vs, v.(string))
	}
}

// Close closes the underlying iterator and marks slurpRawInputIter as finished.
// Parameters:
//   - none
//
// Returns nil.
func (i *slurpRawInputIter) Close() error {
	if i.iter != nil {
		i.iter.Close()
		i.iter = nil
		i.err = io.EOF
	}
	return nil
}

// Name returns the source name from the underlying iterator.
// Parameters:
//   - none
//
// Returns the source file name string.
func (i *slurpRawInputIter) Name() string {
	return i.iter.Name()
}
