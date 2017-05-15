echo
echo "--- Bundling"
echo

BUNDLE_PATH=vendor/bundle
bundle check --path $BUNDLE_PATH || bundle --binstubs --path $BUNDLE_PATH

echo
echo "--- Preparing databases"
echo

dropdb event_sourcery_test || echo 0
createdb event_sourcery_test

echo
echo "+++ Running rake"
echo

time bundle exec rake
