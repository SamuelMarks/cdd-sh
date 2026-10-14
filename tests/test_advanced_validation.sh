#!/bin/sh
# @file tests/test_advanced_validation.sh
# @description Tests discriminator and composition schema validation.
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/.." && pwd)/lib/env.sh"
cd "$(dirname "$0")/.."

./bin/cdd-sh from_openapi -i tests/test_advanced.json --no-github-actions --no-installable-package -o ./tmp_out
./bin/cdd-sh emit classes tests/test_advanced_out.sh

# shellcheck disable=SC1091
. tests/test_advanced_out.sh

echo "Testing BasePet"
if validate_BasePet '{"name": "Fido"}'; then echo "BasePet valid (Expected)"; else echo "BasePet failed (Unexpected)" && exit 1; fi
if validate_BasePet '{"age": 5}'; then echo "BasePet valid (Unexpected)" && exit 1; else echo "BasePet failed (Expected)"; fi

echo "Testing Dog"
if validate_Dog '{"name": "Fido", "bark": true}'; then echo "Dog valid (Expected)"; else echo "Dog failed (Unexpected)" && exit 1; fi
if validate_Dog '{"name": "Fido"}'; then echo "Dog valid (Unexpected)" && exit 1; else echo "Dog failed (Expected)"; fi
if validate_Dog '{"bark": true}'; then echo "Dog valid (Unexpected)" && exit 1; else echo "Dog failed (Expected)"; fi

echo "Testing Pet (oneOf Dog or Cat)"
if validate_Pet '{"name": "Fido", "bark": true}'; then echo "Pet Dog valid (Expected)"; else echo "Pet Dog failed (Unexpected)" && exit 1; fi
if validate_Pet '{"name": "Fido", "meow": true}'; then echo "Pet Cat valid (Expected)"; else echo "Pet Cat failed (Unexpected)" && exit 1; fi
if validate_Pet '{"name": "Fido", "bark": true, "meow": true}'; then echo "Pet Dog+Cat valid (Unexpected)" && exit 1; else echo "Pet Dog+Cat failed (Expected)"; fi

echo "Testing AnyPet (anyOf Dog or Cat)"
if validate_AnyPet '{"name": "Fido", "bark": true}'; then echo "AnyPet Dog valid (Expected)"; else echo "AnyPet Dog failed (Unexpected)" && exit 1; fi
if validate_AnyPet '{"name": "Fido", "bark": true, "meow": true}'; then echo "AnyPet Dog+Cat valid (Expected)"; else echo "AnyPet Dog+Cat failed (Unexpected)" && exit 1; fi
if validate_AnyPet '{"name": "Fido"}'; then echo "AnyPet invalid valid (Unexpected)" && exit 1; else echo "AnyPet invalid failed (Expected)"; fi

rm -rf tmp_out
echo "All advanced tests passed!"
