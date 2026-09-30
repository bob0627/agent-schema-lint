# Fixtures

- `ok/*.json` — schemas that must lint with **no Error** diagnostics (warnings allowed).
- `bad/*.json` — schemas that must produce at least one Error; the expected ASL code
  for each file is listed in [`bad/expected.txt`](./bad/expected.txt).

All fixtures are embedded into `../fixtures_test.mbt` by
[`../scripts/gen_fixture_tests.sh`](../scripts/gen_fixture_tests.sh), so `moon test`
checks every file. After adding or editing a fixture:

```bash
scripts/gen_fixture_tests.sh          # regenerate fixtures_test.mbt
scripts/gen_fixture_tests.sh --check  # verify it is up to date (used by .githooks/pre-commit)
moon test
```

A new bad fixture without an `expected.txt` entry makes the generator fail on purpose.
