
#[test_only]
module cpa::project_tests;
// uncomment this line to import the module
// use cpa::project_manager;

const ENotImplemented: u64 = 0;

#[test]
fun test_cpa() {
    // pass
}

#[test, expected_failure(abort_code = ::cpa::project_tests::ENotImplemented)]
fun test_cpa_fail() {
    abort ENotImplemented
}

