#!/bin/sh

# Parse command line

usage() {
    echo "Usage: runtests.sh [-p RUBY] [-- ARGS]"
    echo ""
    echo "Where RUBY is the ruby binary to use (default 'ruby')"
    echo "and ARGS are passed as command line parameters to the test"
    echo "scripts.  (The '--' must separate runtest parameters from"
    echo "test script parameters)."
}

RUBY="ruby"

while getopts "p:" options; do
    case $options in
	p) RUBY=$OPTARG
	   ;;
	?) usage
	   exit 1
	   ;;
    esac
done

shift `expr $OPTIND - 1`

if [ "$1" = "all" ]; then
    RUBY="ruby"
fi

# Run tests

failed=0

for test in test_*.rb; do
    for ruby in $RUBY; do
	echo ====================
	echo $ruby $test
	echo ====================
	$ruby $test "$@"
	if [ $? != 0 ]; then
	    failed=1
	    break
	fi
   done
done

# Display a message and set exit code appropriately

if [ $failed = 1 ]; then
    echo TESTS FAILED
    exit $failed
fi

echo TESTS PASSED
