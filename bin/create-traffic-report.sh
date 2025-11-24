#!/bin/bash
#
# Analyzer script for messages written into 
# the Error log by Traffic Observation Plugin.
#
# Pipe entire Error log into this script and it
# will output a JSON file.
#
# Mandatory command line option: traffic-type
# See usage.
#

# strict bash behavior: seehttp://redsymbol.net/articles/unofficial-bash-strict-mode/
#set -euo pipefail
IFS=$'\n\t'

# --------------------------------------------------
# Initialization
# --------------------------------------------------

VERBOSE=0

TYPE=""
DATE="$(date +'%Y-%m-%d')"
CONTACT="anonymous"
DESCRIPTION=""

MYTYPE=""
MYDATE=""
MYCONTACT=""
MYDESCRIPTION=""

DESCRIPTION_MAXLENGTH=512

TMP=$(mktemp)
BASICSTATS=$(mktemp)
PERCENTS=$(mktemp)

trap 'cleanup' INT TERM EXIT


# --------------------------------------------------
# Function Library
# --------------------------------------------------

# Loop over STDIN
# while read LINE; do
#	echo "$LINE"
# done < "${1:-/dev/stdin}"

# Read multiline variable, loop over it
# read -r -d '' LINES << 'EOF'
# Item 1
# Item 2
# EOF
# echo "$LINES" | while read LINE; do
# 	echo "X $LINE"
# done



# --------------------------------------------------
# Library Functions
# --------------------------------------------------

function cleanup {
	if [ -f "$TMP" ]; then
		rm "$TMP"
	fi
	if [ -f "$BASICSTATS" ]; then
		rm "$BASICSTATS"
	fi
	if [ -f "$PERCENTS" ]; then
		rm "$PERCENTS"
	fi
}

function usage {

	cat << EOF

Analyzer script for messages written into 
the Error log by Traffic Observation Plugin.

Pipe entire Error log into this script and it
will output a JSON file.

Usage:

$> <STDOUT> | $(basename $0) [options] 

Options:

 -c  --contact                Contact name or email address (optional)
 -d  --date                   Date when traffic occurred. If stretch of time,
                              take last day. (optional)
 -D  --description            A description of the traffic (optional)
 -h  --help                   Print help text and exit.
 -t  --traffic-type           One of "web" / "api" / "mixed" (mandatory option)
 -v  --verbose                Verbose output

Requirements:
This script uses the Gnu awk implementation "gawk". This is a prerequisite.
EOF

	exit 0
}


function vprint {

	if [ $VERBOSE -eq 1 ]; then
		echo "$1"
	fi
}

function prepare_basicstats_script {
read -r -d '' LINES << 'EOF'
BEGIN {
        sum = 0.0 
        sum2 = 0.0
        min = 10e10
        max = -min
}

(NF>0) {
        sum += $1
        sum2 += $1 * $1 
        N++;

        if ($1 > max) {
                max = $1
        }
        if ($1 < min) {
                min = $1
        }

        arr[NR]=$1
}

END{
    asort(arr)

    if (NR%2==1) {
        median = arr[(NR+1)/2]
    }
    else {
        median = (arr[NR/2]+arr[NR/2+1])/2
    }

    if(N>0){
	print "§NumValues§:",N", §Minimum§:",min", §Maximum§:",max", §Range§:",max-min", §Mean§:",sum/N", §Median§:",median", §StdandardDeviation§:",sqrt((sum2 - sum*sum/N)/N)", §Variance§:",(sum2 - sum*sum/N)/N", §CoefficientOfVariation§:",(sqrt((sum2 - sum*sum/N)/N))/(sqrt(sum*sum)/N)
    }else{
	print "§NumValues§: 0, §Minimum§: 0, §Maximum§: 0, §Range§: 0, §Mean§: 0,§Median§: 0, §StdandardDeviation§: 0, §Variance§: 0, §CoefficientOfVariation§: 0"
    }
}

EOF

	echo "$LINES" | while read LINE; do
		echo $LINE  >> $BASICSTATS
	done

}

function prepare_percent_script {
read -r -d '' LINES << 'EOF'
BEGIN{}
{
        sum+=$1;
        i++;
        count[i]=$1;
        country[i]=$2
}
END{
        for (j=1; j<=i; j++) {
                printf "{ §key§: §%-s§, §count§: %i, §percentage§: %6.2f }, ", country[j], count[j], count[j] * 100 / sum
        }
}
EOF

	echo "$LINES" | while read LINE; do
		echo $LINE  >> $PERCENTS
	done

}


function write_report {

	echo -n "{"
	echo -n "\"contact\": \"$CONTACT\","
	echo -n "\"date\": \"$DATE\","
	echo -n "\"description\": \"$DESCRIPTION\","
	echo -n "\"trafficType\": \"$TYPE\","

read -r -d '' LINES << 'EOF'
Protocol distinct
Method distinct
LenFilename num
LenQueryString num
NumQueryStringArgs num
NumReqHeaders num
LenCookies num
NumCookies num
ReqContentType distinct
ReqContentLength num
StatusCode distinct
NumRespHeaders num
RespContentType distinct
RespContentLength num
EOF

	echo "$LINES" | while read LINE; do
		NAME=$(echo "$LINE" | cut -d\  -f1)
		INFOTYPE=$(echo "$LINE" | cut -d\  -f2)
		if [ "$INFOTYPE" == "num" ]; then
			echo -n " \"$NAME\": { "
			cat $TMP | grep -F "tag \"traffic-observation\"" | grep -o -E "\[data [^]]*" | cut -d\" -f2 | tr "'" "\"" | jq -r ".$NAME" | sed -e "/^$/d" | awk -f $BASICSTATS | tr "§" "\"" | sed -e "s/\"\"/\"/g" -e "s/ ,/,/g" | tr -d "\n"
			echo -n "}"
			if [ "$NAME" != "RespContentLength" ]; then
				echo -n ","
			fi

			# echo -n "\"$NAME\": \"$(cat $TMP | wc -l)\","
		fi
		if [ "$INFOTYPE" == "distinct" ]; then
			echo -n " \"$NAME\": [ "
			(cat $TMP | grep -F "tag \"traffic-observation\"" | grep -o -E "\[data [^]]*" | cut -d\" -f2 | tr "'" "\"" | jq -r ".$NAME" | sed -e "/^$/d" | sort | uniq -c | sort -n | awk -f $PERCENTS | tr "§" "\"" | sed -e "s/\"\"/\"/g" -e "s/ ,/,/g") | sed -e "s/}, $/} /g"
			echo -n "], "
		fi
	done

	echo "}"

}

# --------------------------------------------------
# Parameter reading and checking
# --------------------------------------------------

while [ 1 ]
do
	if [ -n "${1-}" ]; then
                ARG="${1-}"
		FIRSTCHAR="$(echo "$ARG " | cut -b1)"
		# The space after $ARG makes sure CLI option "-e" (an echo option) is also accepted
                if [ $FIRSTCHAR == "-" ]; then
                        case $1 in
			-c) export MYCONTACT="${2-}"; shift;;
			--contact) export MYCONTACT="${2-}"; shift;;
			-d) export MYDATE="${2-}"; shift;;
			--date) export MYDATE="${2-}"; shift;;
			-D) export MYDESCRIPTION="${2-}"; shift;;
			--description) export MYDESCRIPTION="${2-}"; shift;;
                        -h) usage; exit;;
                        --help) usage; exit;;
			-t) export MYTYPE="${2-}"; shift;;
			--traffic-type) export MYTYPE="${2-}"; shift;;
			-v) export VERBOSE=1;;
			--verbose) export VERBOSE=1;;
			*) echo "Unknown option $1. This is fatal. Aborting."; exit 1;;
			esac
			if [ -n "${1-}" ]; then
                        	shift
			fi
                else
                        break
                fi
        else
                break
        fi
done

if [ -z "$MYTYPE" ]; then
	echo "Mandatory parameter traffic-type not passed. This is fatal. Aborting."
	exit 1
fi
echo "$MYTYPE" | grep -q -E "^(web|api|mixed)$"
if [ $? -eq 1 ]; then
	echo "Parameter traffic-type is not one of \"web\" / \"api\" / \"mixed\". This is fatal. Aborting."
	exit 1
else
	TYPE="$MYTYPE"
fi

if [ "$MYCONTACT" != "" ]; then
	CONTACT="$MYCONTACT"
fi
if [ "$MYDATE" != "" ]; then
	DATE="$MYDATE"
fi

if [ $(echo "$MYDESCRIPTION" | wc --bytes) -gt $DESCRIPTION_MAXLENGTH ]; then
	echo "Description is longer than the limit of $DESCRIPTION_MAXLENGTH bytes. This is fatal. Aborting."
	exit 1
fi

if [ "$MYDESCRIPTION" != "" ]; then
	DESCRIPTION="$MYDESCRIPTION"
fi


if [ -t 0 ]; then
	echo "No STDIN available. See usage. This is fatal. Aborting."
	exit 1
fi

if [ "$(which gawk | wc -l)" -ne 1 ]; then
	echo "Gnu awk (gawk) not found. Please install it. This is fatal. Aborting."
	exit 1
fi

cat > $TMP

prepare_basicstats_script 
prepare_percent_script 

# --------------------------------------------------
# Main program
# --------------------------------------------------

write_report

cleanup
