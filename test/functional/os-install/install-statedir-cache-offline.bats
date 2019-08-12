#!/usr/bin/env bats

# Author: John Akre
# Email: john.w.akre@intel.com

load "../testlib"


#TODO: 
#	- Manifest.tar: When is this used?
#	- Manifest.<hash>: When is this used?
test_setup() {

	create_test_environment -e "$TEST_NAME" 10
	create_bundle -n os-core -f /core "$TEST_NAME"
	#set_content_url "badurl"

	statedir_cache_path="${TEST_DIRNAME}/testfs/statedir-cache"

	# Populate statedir cache
	sudo mkdir -m 700 -p "$statedir_cache_path"
	sudo mkdir -m 700 "$statedir_cache_path"/staged
	sudo mkdir -m 755 "$statedir_cache_path"/10
	sudo cp "$WEBDIR"/10/Manifest.MoM "$statedir_cache_path"/10
	sudo cp "$WEBDIR"/10/Manifest.MoM.sig "$statedir_cache_path"/10
	sudo cp "$WEBDIR"/10/Manifest.os-core "$statedir_cache_path"/10
	sudo rsync -r "$WEBDIR"/10/files/* "$statedir_cache_path"/staged --exclude="*.tar"

}

@test "INS017: statedir offline cache hits" {

	# 
	# Make it an export
	#statedir_cache_path="${TEST_DIRNAME}/testfs/statedir-cache"
	run sudo sh -c "$SWUPD os-install --versionurl=badurl --statedir-cache $statedir_cache_path $SWUPD_OPTS_NO_PATH $TARGETDIR -V 10"

	assert_status_is "$SWUPD_OK"
	expected_output=$(cat <<-EOM
		Failed to connect to update server, must update from state dir cache
		Installing OS version 10
		Curl was not initialized, skipping pack download
		Checking for corrupt files
		No extra files need to be downloaded
		Installing base OS and selected bundles
		Inspected 2 files
		  2 files were missing
		    2 of 2 missing files were installed
		    0 of 2 missing files were not installed
		Calling post-update helper scripts
		Installation successful
	EOM
	)
	assert_is_output "$expected_output"
	assert_file_exists "$TARGETDIR"/usr/share/clear/bundles/os-core
	assert_file_exists "$TARGETDIR"/core
	
}

@test "INS017: statedir offline Manifest miss" {

	# 
	# Make it an export
	#statedir_cache_path="${TEST_DIRNAME}/testfs/statedir-cache"
	sudo rm "$statedir_cache_path"/10/Manifest.os-core
	run sudo sh -c "$SWUPD os-install --versionurl=badurl --statedir-cache $statedir_cache_path $SWUPD_OPTS_NO_PATH $TARGETDIR -V 10"

	assert_status_is "$SWUPD_COULDNT_LOAD_MANIFEST"
	expected_output=$(cat <<-EOM
		Failed to connect to update server, must update from state dir cache
		Installing OS version 10
		Error: Curl hasn't been initialized
		Error: Failed to retrieve 10 os-core manifest
		Error: Unable to download manifest os-core version 10, exiting now
		Installation failed
	EOM
	)
	assert_is_output "$expected_output"
	assert_file_not_exists "$TARGETDIR"/usr/share/clear/bundles/os-core
	assert_file_not_exists "$TARGETDIR"/core
	
}

@test "INS017: statedir offline sig miss" {

	sudo rm "$statedir_cache_path"/10/Manifest.MoM.sig
	run sudo sh -c "$SWUPD os-install --versionurl=badurl --statedir-cache $statedir_cache_path $SWUPD_OPTS_NO_PATH $TARGETDIR -V 10"

	assert_status_is "$SWUPD_COULDNT_LOAD_MOM"
	expected_output=$(cat <<-EOM
		Failed to connect to update server, must update from state dir cache
		Installing OS version 10
		Error: Curl hasn't been initialized
		Warning: Removing corrupt Manifest.MoM artifacts and re-downloading...
		Error: Curl hasn't been initialized
		Error: Failed to retrieve 10 MoM manifest
		Error: Unable to download/verify 10 Manifest.MoM
		Installation failed
	EOM
	)
	#Error: FAILED TO VERIFY SIGNATURE OF Manifest.MoM version 10!!!
	assert_is_output "$expected_output"
	assert_file_not_exists "$TARGETDIR"/usr/share/clear/bundles/os-core
	assert_file_not_exists "$TARGETDIR"/core
	
}

test_teardown() {
	return
}

@test "INS017: files miss" {

	sudo rm -r "$statedir_cache_path"/staged
	run sudo sh -c "$SWUPD os-install --versionurl=badurl --statedir-cache $statedir_cache_path $SWUPD_OPTS_NO_PATH $TARGETDIR -V 10"

	assert_status_is "$SWUPD_COULDNT_DOWNLOAD_FILE"
	expected_output=$(cat <<-EOM
		Failed to connect to update server, must update from state dir cache
		Installing OS version 10
		Curl was not initialized, skipping pack download
		Checking for corrupt files
		Error: Curl - Invalid parallel download handle
		Error: Unable to download necessary files for this OS release
		Installation failed
	EOM
	)
	assert_is_output "$expected_output"
	assert_file_not_exists "$TARGETDIR"/usr/share/clear/bundles/os-core
	assert_file_not_exists "$TARGETDIR"/core

}
