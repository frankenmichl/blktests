
properties=""
timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S')

content=""
failed=0; total=0; skipped=0; good=0

passed() {
	local dev=$1
	local group=$2
	local test=$3
	local runtime=$4

	good=$(expr $good + 1)
	
	content="$content
	<testcase name=\"$group/$test\" time=\"$runtime\" classname=\"$dev/$group/$test\">
	<system-out>
        <![CDATA[  
                   $(cat "${seqres}")
           ]]>
	</system-out>
	</testcase>"
}

failed() {
	local dev=$1
	local group=$2
	local test=$3
	local runtime=$4
	local seqres="results/$dev/$group/$test"
	
	failed=$(expr $failed + 1)

	if [ -f "$seqres.dmesg" ]; then
		errtype="<failure type=\"dmesg\" message=\"$group/$test failed\"/>"
		errstr=$(cat ${seqres}.dmesg)
	else
		errtype="<failure type=\"output\" message=\"$group/$test failed\"></failure>"		
		errstr=$(cat "${seqres}.out.bad")
	fi

	content="$content
	<testcase name=\"$group/$test\" errors=\"1\" time=\"$runtime\" classname=\"$dev/$group/$test\">
	$errtype
	<system-out>
		<![CDATA[
			$errstr
		   ]]>
	</system-out>
	</testcase>"

}

skipped() {
	local dev=$1
	local group=$2
	local test=$3
	
	skipped=$(expr $skipped + 1)
	
	content="$content
	<testcase name=\"$group/$test\" errors=\"0\" classname=\"$dev/$group\">
	<skipped/>
	</testcase>"	
}



parse_testresult() {
	local dev=$1
	local group=$2
	local test=$3
	local seqres="results/$dev/$group/$test"
	if [ -f "$seqres" ]; then
		echo $group/$test
		status=$(grep "^status" $seqres | cut -f 2)
	      	runtime=$(grep "^runtime" $seqres  | cut -f 2 | cut -d '.' -f 1)
		if [ "$status" == "pass" ];
		then
			passed $dev $group $test $runtime
		else
			failed $dev $group $test $runtime
		fi
	else
		skipped $dev $group $test
	fi
	
	
}

parse_groups() {
	local dev=$1
	for group in $(ls results/$dev);
	do
		echo $group
		tests=$(ls tests/$group/??? | cut -d '/' -f 3)
		for test in $tests;
		do
			total=$(expr $total + 1)
			parse_testresult $dev $group $test
		done
	done
}

write_report() {
	local outfile=$1
	cat <<EOF > "$outfile"
  <testsuite failures="$failed" name="blktests" tests="$total" errors="$failed" hostname="$(hostname)" time="$timestamp">
    $content
  </testsuite>
EOF
	if [ $failed -eq 0 ]; then
		result="SUCCESS"
	else
		result="FAILURE"
	fi
	echo "[$result] Testsuite summary: tests=$total good=$good errors=$failed skipped=$skipped"
}



if [ -r config ]; then
        . config
fi

if [ -z "$TEST_DEVS" ]; then
        TEST_DEVS=( nodev )
fi

echo "${TEST_DEVS[@]}"

for dev in ${TEST_DEVS[@]};
do
	parse_groups $dev
done
write_report "/tmp/blktests.xml"

