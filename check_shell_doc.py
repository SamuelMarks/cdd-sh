import os
import re

total_functions = 0
documented_functions = 0

for root, _, files in os.walk('.'):
    for file in files:
        if file.endswith('.sh') and not root.startswith('./tests') and not root.startswith('./tmp_out') and not root.startswith('./temp_sdk'):
            path = os.path.join(root, file)
            with open(path, 'r') as f:
                content = f.read()
                # Find functions: func_name() {
                functions = re.finditer(r'^[ \t]*([a-zA-Z_0-9]+)\(\)[ \t]*\{', content, re.MULTILINE)
                for m in functions:
                    func_name = m.group(1)
                    total_functions += 1
                    # Check if there's a comment right above it
                    start = m.start()
                    before = content[:start].strip().split('\n')
                    if before and before[-1].strip().startswith('#'):
                        documented_functions += 1
                    else:
                        print(f"Missing doc: {func_name} in {path}")

print(f"Total: {total_functions}, Documented: {documented_functions}")
