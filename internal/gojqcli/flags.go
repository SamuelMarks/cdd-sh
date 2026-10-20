// Package gojqcli implements reflection-based CLI flag parsing and help formatting.
package gojqcli

import (
	"fmt"
	"reflect"
	"strconv"
	"strings"
)

// assignFlagValue assigns a parsed CLI flag value to the target reflection field `val`.
// Parameters:
//   - arg: The flag name being processed (e.g., "-r" or "--raw-output").
//   - val: The reflection Value of the target field on the options struct.
//   - args: The full CLI arguments slice.
//   - idx: Pointer to the current argument index in `args`.
//   - longToPositional: Set of long flag names marked with `positional:""`.
//   - positionalVal: Pointer to the active positional slice reflection Value.
//   - mapKeys: Set of map keys already populated during this flag parse pass.
//
// Returns any flag parsing error encountered.
func assignFlagValue(
	arg string,
	val reflect.Value,
	args []string,
	idx *int,
	longToPositional map[string]struct{},
	positionalVal *reflect.Value,
	mapKeys map[string]struct{},
) error {
	switch val.Kind() {
	case reflect.Bool:
		val.SetBool(true)
	case reflect.String:
		if *idx++; *idx >= len(args) {
			return newCliError(ErrKindFlagParse, exitCodeFlagParseErr, fmt.Sprintf("expected argument for flag `%s'", arg))
		}
		val.SetString(args[*idx])
	case reflect.Pointer:
		if val.Type().Elem().Kind() == reflect.Int {
			if *idx++; *idx >= len(args) {
				return newCliError(ErrKindFlagParse, exitCodeFlagParseErr, fmt.Sprintf("expected argument for flag `%s'", arg))
			}
			v, err := strconv.Atoi(args[*idx])
			if err != nil {
				return newCliError(ErrKindFlagParse, exitCodeFlagParseErr, fmt.Sprintf("invalid argument for flag `%s': %v", arg, err))
			}
			val.Set(reflect.New(val.Type().Elem()))
			val.Elem().SetInt(int64(v))
		}
	case reflect.Slice:
		if len(arg) > 2 && arg[:2] == "--" {
			if _, isPos := longToPositional[arg[2:]]; isPos {
				if positionalVal.IsValid() {
					for positionalVal.Len() > val.Len() {
						val.Set(reflect.Append(val, reflect.Zero(val.Type().Elem())))
					}
				}
				*positionalVal = val
				return nil
			}
		}
		if *idx++; *idx >= len(args) {
			return newCliError(ErrKindFlagParse, exitCodeFlagParseErr, fmt.Sprintf("expected argument for flag `%s'", arg))
		}
		val.Set(reflect.Append(val, reflect.ValueOf(args[*idx])))
	case reflect.Map:
		if *idx += 2; *idx >= len(args) {
			return newCliError(ErrKindFlagParse, exitCodeFlagParseErr, fmt.Sprintf("expected 2 arguments for flag `%s'", arg))
		}
		if val.IsNil() {
			val.Set(reflect.MakeMap(val.Type()))
		}
		name := args[*idx-1]
		if _, exists := mapKeys[name]; !exists {
			mapKeys[name] = struct{}{}
			val.SetMapIndex(reflect.ValueOf(name), reflect.ValueOf(args[*idx]))
		}
	}
	return nil
}

// parseFlags parses command-line arguments into the struct pointed to by opts based on struct tags.
// Parameters:
//   - args: The slice of CLI arguments to parse.
//   - opts: Pointer to the options struct annotated with `short`, `long`, and `positional` tags.
//
// Returns the remaining non-flag positional arguments and any flag parsing error.
func parseFlags[T any](args []string, opts *T) ([]string, error) {
	rest := make([]string, 0, len(args))
	val := reflect.ValueOf(opts).Elem()
	typ := val.Type()
	longToValue := map[string]reflect.Value{}
	longToPositional := map[string]struct{}{}
	shortToValue := map[string]reflect.Value{}
	for i := range val.NumField() {
		if flag, ok := typ.Field(i).Tag.Lookup("long"); ok {
			longToValue[flag] = val.Field(i)
			if _, ok := typ.Field(i).Tag.Lookup("positional"); ok {
				longToPositional[flag] = struct{}{}
			}
		}
		if flag, ok := typ.Field(i).Tag.Lookup("short"); ok {
			shortToValue[flag] = val.Field(i)
		}
	}
	mapKeys := map[string]struct{}{}
	var positionalVal reflect.Value
	var optsDone bool
	for i := 0; i < len(args); i++ {
		arg := args[i]
		var (
			fval      reflect.Value
			ok        bool
			shortopts string
		)
		switch {
		case optsDone:
			// Skip option parsing after `--`.
		case arg == "--":
			optsDone = true
			continue
		case strings.HasPrefix(arg, "--"):
			if fval, ok = longToValue[arg[2:]]; !ok {
				if j := strings.IndexByte(arg, '='); j >= 0 {
					if fval, ok = longToValue[arg[2:j]]; ok {
						if fval.Kind() == reflect.Bool {
							return nil, newCliError(ErrKindFlagParse, exitCodeFlagParseErr, fmt.Sprintf("boolean flag `%s' cannot have an argument", arg[:j]))
						}
						args[i] = arg[j+1:]
						arg = arg[:j]
						i--
					}
				}
				if !ok {
					return nil, newCliError(ErrKindFlagParse, exitCodeFlagParseErr, fmt.Sprintf("unknown flag `%s'", arg))
				}
			}
		case len(arg) > 1 && arg[0] == '-':
			var skip bool
			for k := 1; k < len(arg); k++ {
				opt := arg[k : k+1]
				if fval, ok = shortToValue[opt]; ok {
					if fval.Kind() != reflect.Bool {
						break
					}
				} else if !("A" <= opt && opt <= "Z" || "a" <= opt && opt <= "z") {
					skip = true
					break
				}
			}
			if !skip && (len(arg) > 2 || !ok) {
				shortopts = arg[1:]
			}
		}
		if shortopts == "" {
			if !ok {
				if positionalVal.IsValid() && len(rest) > 0 {
					positionalVal.Set(reflect.Append(positionalVal, reflect.ValueOf(arg)))
				} else {
					rest = append(rest, arg)
				}
				continue
			}
			if err := assignFlagValue(arg, fval, args, &i, longToPositional, &positionalVal, mapKeys); err != nil {
				return nil, err
			}
			continue
		}
		for shortopts != "" {
			opt := shortopts[:1]
			if fval, ok = shortToValue[opt]; !ok {
				return nil, newCliError(ErrKindFlagParse, exitCodeFlagParseErr, fmt.Sprintf("unknown flag `%s'", opt))
			}
			if fval.Kind() != reflect.Bool && len(shortopts) > 1 {
				if shortopts[1] == '=' {
					args[i] = shortopts[2:]
				} else {
					args[i] = shortopts[1:]
				}
				i--
				shortopts = ""
			} else {
				shortopts = shortopts[1:]
			}
			if err := assignFlagValue("-"+opt, fval, args, &i, longToPositional, &positionalVal, mapKeys); err != nil {
				return nil, err
			}
		}
	}
	return rest, nil
}

// formatFlags generates a formatted help string describing all fields of the options struct.
// Parameters:
//   - opts: Pointer to the options struct containing `short`, `long`, `args`, and `description` tags.
//
// Returns the formatted command options help text.
func formatFlags[T any](opts *T) string {
	val := reflect.ValueOf(opts).Elem()
	typ := val.Type()
	var sb strings.Builder
	sb.WriteString("Command Options:\n")
	for i := range typ.NumField() {
		tag := typ.Field(i).Tag
		if i == typ.NumField()-1 {
			sb.WriteString("\nHelp Option:\n")
		}
		sb.WriteString("  ")
		var short bool
		if flag, ok := tag.Lookup("short"); ok {
			sb.WriteString("-")
			sb.WriteString(flag)
			short = true
		} else {
			sb.WriteString("  ")
		}
		m := sb.Len()
		if flag, ok := tag.Lookup("long"); ok {
			if short {
				sb.WriteString(", ")
			} else {
				sb.WriteString("  ")
			}
			sb.WriteString("--")
			sb.WriteString(flag)
		}
		if args, ok := tag.Lookup("args"); ok {
			sb.WriteString(" ")
			sb.WriteString(args)
		}
		sb.WriteString(strings.Repeat(" ", 24-(sb.Len()-m)))
		sb.WriteString(tag.Get("description"))
		sb.WriteString("\n")
	}
	return sb.String()
}
