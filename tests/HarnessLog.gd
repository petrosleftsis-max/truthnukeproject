class_name HarnessLog
## Where a driver writes its results.
##
## The runner hands the log folder over in the environment rather than each
## driver knowing a path, because the drivers used to carry an absolute one and
## that made the whole harness run on exactly one machine.
##
## Run a driver by hand with no runner around it and the results land in the
## copy's own user:// instead, which is somewhere rather than nowhere.
static func path_for(suite: String) -> String:
	var dir := OS.get_environment("MOT_TEST_LOG_DIR")
	if dir.is_empty():
		return "user://%s_test_result.txt" % suite
	return "%s/%s_test_result.txt" % [dir, suite]
