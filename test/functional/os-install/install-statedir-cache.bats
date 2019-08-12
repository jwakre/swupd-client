#!/usr/bin/env bats

# Author: John Akre
# Email: john.w.akre@intel.com

load "../testlib"


#TODO:
#	- Manifest.tar, Manifest.<hash>
#	- test numbers
#	- test names
#	- test descriptions
#	- Add test for missing Manifest.sig
test_setup() {

	create_test_environment -e "$TEST_NAME" 10
	create_bundle -n os-core -f /core "$TEST_NAME"

	statedir_cache_path="${TEST_DIRNAME}/testfs/statedir-cache"

	# Populate statedir cache
	sudo mkdir -m 700 -p "$statedir_cache_path"
	sudo mkdir -m 700 "$statedir_cache_path"/staged
	sudo mkdir -m 755 "$statedir_cache_path"/10
	sudo cp "$WEBDIR"/10/Manifest.MoM "$statedir_cache_path"/10
	sudo cp "$WEBDIR"/10/Manifest.MoM.sig "$statedir_cache_path"/10
	sudo cp "$WEBDIR"/10/Manifest.os-core "$statedir_cache_path"/10
	sudo touch "$statedir_cache_path"/pack-os-core-from-0-to-10.tar
	sudo rsync -r "$WEBDIR"/10/files/* "$statedir_cache_path"/staged --exclude="*.tar"

}

@test "INS017: statedir cache hits" {
	# 
	# Make it an export
	#statedir_cache_path="${TEST_DIRNAME}/testfs/statedir-cache"
	run sudo sh -c "$SWUPD os-install --statedir-cache $statedir_cache_path $SWUPD_OPTS_NO_PATH $TARGETDIR"

	assert_status_is "$SWUPD_OK"
	expected_output=$(cat <<-EOM
		Installing OS version 10 (latest)
		No packs need to be downloaded
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

@test "INS017: statedir cache misses" {
	# 
	# Make it an export - it is one-off, so maybe not..
	sudo rm "$statedir_cache_path"/10/Manifest.os-core
	sudo rm "$statedir_cache_path"/pack-os-core-from-0-to-10.tar
	sudo rm -r "$statedir_cache_path"/staged
	run sudo sh -c "$SWUPD os-install --statedir-cache $statedir_cache_path $SWUPD_OPTS_NO_PATH $TARGETDIR"

	assert_status_is "$SWUPD_OK"
	expected_output=$(cat <<-EOM
		Installing OS version 10 (latest)
		Downloading packs for:
		 - os-core
		Finishing packs extraction...
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

@test "INS017: Missing Fullfile" {
	# This test is needed because downloaded pack will populate fullfiles
	# 
	# Make it an export - it is one-off, so maybe not..
	sudo rm -r "$statedir_cache_path"/staged
	run sudo sh -c "$SWUPD os-install --statedir-cache $statedir_cache_path $SWUPD_OPTS_NO_PATH $TARGETDIR"

	assert_status_is "$SWUPD_OK"
	expected_output=$(cat <<-EOM
		Installing OS version 10 (latest)
		No packs need to be downloaded
		Checking for corrupt files
		Starting download of remaining update content. This may take a while...
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

@test "INS017: Corrupt manifest" {

	sudo sh -c "echo invalid > ${statedir_cache_path}/10/Manifest.os-core"
	run sudo sh -c "$SWUPD os-install --statedir-cache $statedir_cache_path $SWUPD_OPTS_NO_PATH $TARGETDIR"

	assert_status_is "$SWUPD_OK"
	expected_output=$(cat <<-EOM
		Installing OS version 10 (latest)
		Warning: Removing corrupt Manifest.os-core artifacts and re-downloading...
		No packs need to be downloaded
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

#TODO: Need corrupt statedir for retry over network
#	- Hmm can we even handle corrupt statedir? Maybe don't worry for cache...
#		** It looks like a successful copy would skip retries, even corrupt
#		** Probably even for the statedir... Bad statedir content can't be handled for manifests
#		** Can probably check for corrupt files
