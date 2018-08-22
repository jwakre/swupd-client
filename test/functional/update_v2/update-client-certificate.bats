#!/usr/bin/env bats

load "../testlib"

TEST_DIR_PATH=$(dirname "$(realpath "$TEST_NAME")/$TEST_NAME")

server_pub="$TEST_DIR_PATH/server-pub.pem"
server_key="$TEST_DIR_PATH/server-key.pem"
client_pub="$TEST_DIR_PATH/client-pub.pem"
client_key="$TEST_DIR_PATH/client-key.pem"

global_setup() {

	create_test_environment "$TEST_NAME"
	create_test_environment "$TEST_NAME" 100

	create_bundle -n test-bundle -f /usr/bin/test-file "$TEST_NAME"

	run sudo sh -c "mkdir -p $CLIENT_CERT_DIR"

	# create client/server certificates
	generate_certificate $client_key $client_pub
	generate_certificate $server_key $server_pub

	# add server pub key to trust store
	create_trusted_cacert $server_pub

	start_web_server -c $client_pub -p $server_pub -k $server_key
}

test_setup() {

	set_current_version "$TEST_NAME" 10

	# create client certificate in expected directory
	run sudo sh -c "cp $client_key $CLIENT_CERT"
	run sudo sh -c "cat $client_pub >> $CLIENT_CERT"
}

test_teardown() {

	run sudo sh -c "rm -f $CLIENT_CERT"
	clean_state_dir "$TEST_NAME"
}

global_teardown() {

	destroy_web_server
	destroy_trusted_cacert
	destroy_test_environment "$TEST_NAME"
}

@test "update with valid client cert" {

	run sudo sh -c "$SWUPD update $SWUPD_OPTS_HTTPS"

	assert_status_is 0
}

@test "update with no client cert" {

	# remove client certificate
	run sudo sh -c "rm $CLIENT_CERT"

	run sudo sh -c "$SWUPD update $SWUPD_OPTS_HTTPS"
	assert_status_is "$ECURL_INIT"

	expected_output=$(cat <<-EOM
			Curl: Problem with the local client SSL certificate
	EOM
	)
	assert_in_output "$expected_output"
}

@test "update with invalid client cert" {

	# make client certificate invalid
	run sudo sh -c "echo foo > $CLIENT_CERT"

	run sudo sh -c "$SWUPD update $SWUPD_OPTS_HTTPS"
	assert_status_is "$ECURL_INIT"

	expected_output=$(cat <<-EOM
			Curl: Problem with the local client SSL certificate
	EOM
	)
	assert_in_output "$expected_output"
}
