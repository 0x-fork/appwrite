#!/bin/sh
# Tests the utopia extension from the repository root of an image that loads it. Canvas and
# Font are always on: canvas.php and packages/image/tests. The other libraries are the names
# src/lib.rs passes to enabled(), and each must have a parity corpus at tests/<name>.php.
# For each library, on its own:
#   - the extension serves the library's classes only when _APP_EXTENSION_LIBRARIES names it
#     (the corpus exits non-zero when the other implementation loaded),
#   - packages/<name>/tests pass on the extension,
#   - the corpus prints the same on PHP and on the extension.
# Then every corpus again with all libraries on at once, as Cloud runs them.
set -eu

tests=crates/extension/tests
libraries=$(grep -o 'enabled("[a-z-]*")' crates/extension/src/lib.rs | sed 's/enabled("\(.*\)")/\1/' | sort -u)
[ -n "$libraries" ] || { echo "no libraries found in crates/extension/src/lib.rs" >&2; exit 1; }
all=$(echo "$libraries" | paste -sd, -)
output=$(mktemp -d)
trap 'rm -r "$output"' EXIT

php --ri utopia > /dev/null
php "$tests/canvas.php" > /dev/null
vendor/bin/phpunit --no-configuration --bootstrap vendor/autoload.php packages/image/tests

for library in $libraries; do
    echo "== $library" >&2
    [ -f "$tests/$library.php" ] || { echo "missing parity corpus $tests/$library.php" >&2; exit 1; }
    _APP_EXTENSION_LIBRARIES=$library vendor/bin/phpunit --no-configuration --bootstrap vendor/autoload.php "packages/$library/tests"
    _APP_EXTENSION_LIBRARIES= php "$tests/$library.php" > "$output/$library.php.jsonl"
    _APP_EXTENSION_LIBRARIES=$library php "$tests/$library.php" > "$output/$library.rust.jsonl"
    diff "$output/$library.php.jsonl" "$output/$library.rust.jsonl"
    [ -s "$output/$library.rust.jsonl" ] || { echo "$library corpus printed nothing" >&2; exit 1; }
done

echo "== $all" >&2
for library in $libraries; do
    _APP_EXTENSION_LIBRARIES=$all php "$tests/$library.php" > "$output/$library.all.jsonl"
    diff "$output/$library.php.jsonl" "$output/$library.all.jsonl"
done
