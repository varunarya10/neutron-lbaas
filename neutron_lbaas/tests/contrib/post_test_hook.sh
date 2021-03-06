#!/bin/bash

set -xe

NEUTRON_LBAAS_DIR="$BASE/new/neutron-lbaas"
TEMPEST_DIR="$BASE/new/tempest"
SCRIPTS_DIR="/usr/local/jenkins/slave_scripts"

testenv=${1:-"apiv2"}

if [ "$testenv" = "lbaasv1" ]; then
    testenv="apiv1"
elif [ "$testenv" = "lbaasv2" ]; then
    testenv="apiv2"
fi

function generate_testr_results {
    # Give job user rights to access tox logs
    sudo -H -u $owner chmod o+rw .
    sudo -H -u $owner chmod o+rw -R .testrepository
    if [ -f ".testrepository/0" ] ; then
        subunit-1to2 < .testrepository/0 > ./testrepository.subunit
        python $SCRIPTS_DIR/subunit2html.py ./testrepository.subunit testr_results.html
        gzip -9 ./testrepository.subunit
        gzip -9 ./testr_results.html
        sudo mv ./*.gz /opt/stack/logs/
    fi
}

owner=tempest
# Configure the api tests to use the tempest.conf set by devstack.
sudo cp $TEMPEST_DIR/etc/tempest.conf $NEUTRON_LBAAS_DIR/neutron_lbaas/tests/tempest/etc

# Set owner permissions according to job's requirements.
cd $NEUTRON_LBAAS_DIR
sudo chown -R $owner:stack $NEUTRON_LBAAS_DIR

sudo_env=" OS_TESTR_CONCURRENCY=1"

if [ "$testenv" = "apiv2" ]; then
    sudo_env+="OS_TEST_PATH=$NEUTRON_LBAAS_DIR/neutron_lbaas/tests/tempest/v2/api"
elif [ "$testenv" = "apiv1" ]; then
    sudo_env+="OS_TEST_PATH=$NEUTRON_LBAAS_DIR/neutron_lbaas/tests/tempest/v1/api"
else
    echo "ERROR: unsupported testenv: $testenv"
    exit 1
fi

# Run tests
echo "Running neutron lbaas $testenv test suite"
set +e

sudo -H -u $owner $sudo_env tox -e $testenv
# sudo -H -u $owner $sudo_env testr init
# sudo -H -u $owner $sudo_env testr run

testr_exit_code=$?
set -e

# Collect and parse results
generate_testr_results
exit $testr_exit_code
