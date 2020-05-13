#!/bin/bash

echo "--- Automated CBE testing ---"

produce_pattern() {
	local pattern="$1"
	local size="$2"
	[ "$pattern" = "" ] && exit 1

	local N=16384
	# prints numbers until N and uses pattern as delimiter and
	# generates about 85 KiB of data with a 1 byte pattern
	seq -s "$pattern" $N | dd count=1 bs=$size 2>/dev/null
}

test_write_1() {
	local data_file="$1"
	local offset=$2
	local pattern="$offset"

	local pattern_file="/tmp/pattern.$pattern"
	produce_pattern "$pattern" "4096" > $pattern_file
	dd bs=4096 count=1 if=$pattern_file of=$data_file seek=$offset 2>/dev/null || exit 1
}

test_read_compare_1() {
	local data_file="$1"
	local offset=$2
	local pattern="$offset"

	local pattern_file="/tmp/pattern.$pattern"
	produce_pattern "$pattern" "4096" > $pattern_file
	rm $pattern_file.out 2>/dev/null

	dd bs=4096 count=1 if=$data_file of=$pattern_file.out skip=$offset 2>/dev/null || exit 1
	local sha1=$(sha1sum $pattern_file)
	local sha1_sum=${sha1:0:40}

	local sha1out=$(sha1sum $pattern_file.out)
	local sha1out_sum=${sha1out:0:40}

	if [ "$sha1_sum" != "$sha1out_sum" ]; then
		echo "mismatch for block $offset:"
		echo "  expected: $sha1_sum"
		echo -n "  "
		cat $pattern_file | dd bs=32 count=1 2>/dev/null; echo
		echo "  got: $sha1out_sum"
		echo -n "  "
		cat $pattern_file.out | dd bs=32 count=1 2>/dev/null; echo
		return 1
	fi
}

test_create_snapshot() {
	local cbe_dir="$1"

	echo "Create snapshot"
	echo true > $cbe_dir/control/create_snapshot
}

test_list_snapshots() {
	local cbe_dir="$1"

	echo "List content of '$cbe_dir'"
	ls -l $cbe_dir/snapshots
}

test_discard_snapshot() {
	local cbe_dir="$1"
	local snap_id=$2

	echo "Discard snapshot with id: $snap_id"
	echo $snap_id > $cbe_dir/control/discard_snapshot
}

test_rekey() {
	local cbe_dir="$1"

	echo "Start rekeying"
	echo on > $cbe_dir/control/rekey
	echo "Reykeying started"
}

test_rekey_state() {
	local cbe_dir="$1"
	local state="$(< $cbe_dir/control/rekey)"

	echo "Rekeying state: $state"
}

wait_for_rekeying() {
	local cbe_dir="$1"

	echo "Wait for rekeying to finish..."
	while : ; do
		local file_content="$(< $cbe_dir/control/rekey)"
		local state="${file_content:0:4}"
		if [ "$state" = "idle" ]; then
			local result="${file_content:5}"
			echo "Reykeying done: $result"
			break;
		fi
		sleep 2
	done
}

main() {
	local cbe_dir="/dev/cbe"
	local data_file="$cbe_dir/current/data"

	ls -l $cbe_dir

	for i in $(seq 3); do
		echo "Run $i:"
		test_write_1 "$data_file"  "0"
		test_write_1 "$data_file"  "8"
		test_write_1 "$data_file" "16"
		test_create_snapshot "$cbe_dir"

		test_read_compare_1 "$data_file" "0"
		test_read_compare_1 "$data_file" "8"

		test_rekey "$cbe_dir"

		test_read_compare_1 "$data_file" "0"
		test_rekey_state "$cbe_dir"
		test_read_compare_1 "$data_file" "8"
		test_rekey_state "$cbe_dir"
		test_read_compare_1 "$data_file" "16"

		wait_for_rekeying "$cbe_dir"
		echo "Run $i done"
	done

	echo "--- Automated CBE testing finished, shell is yours ---"
}

main "$@"

# just drop into shell
# exit 0
