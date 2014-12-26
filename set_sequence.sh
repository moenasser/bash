#!/bin/bash

## . ${IM_SRC}/sdk/bin/colors

usage(){
	cat <<USAGE

`echo $( basename $0) `  -h  |  [-gvi] -s SEQ_NAME   [num]
 
	`echo Sets or Gets outbound/inbound sequence values.`
	Auto adjusts for Oracle or Sybase
	
	-s	X	Where X is the name of the sequence, eg: "TRADEWARE", "DESKROUTER","ENGARDCDB",etc..
			(Use tab-tab autocomplete for names of sequences)
	
	num		New value to set the sequence to (not needed with `echo -g` option).
	
	-g		`echo GET`s the current sequence value instead of setting the value to `echo num`.
			(Does not alter DB. Only reads from it)
	
	-i 		Sets the `echo inbound` seq instead of outbound
	
	-h		Print this help and exit 
	
	-v		verbose
	
	Examples :
	$> `echo $( basename $0) ` -s TRADEWARE -g	###  Get the current value
	$> `echo $( basename $0) ` -s TRADEWARE 1	###  Set oubound to 1
	$> `echo $( basename $0) ` -s TRADEWARE -i -g	###  Get current inbound value
	$> `echo $( basename $0) ` -s TRADEWARE -i 1	###  Set inbound to 1
					  					
USAGE
}





## We really shouldn't run this if the reporter is running
## Prints 1 if reporter is running. 0 otherwise. 
_is_reporter_running(){
	local rpid=`run_service pid reporter 2>/dev/null`
	if [ "x$rpid" != "x" ];then
		echo 1;
	else
		echo 0;
	fi
}



OUTBOUND=1
VALUE=
SEQNAME=
GET=
SQL=
VERB='-q'



while getopts "vhigs:" opt
do
	case "$opt" in
		g  ) GET=1;
		;;
		i  ) OUTBOUND=0; 
		;;
		h  ) usage;  exit 0;
		;;
		s  ) SEQNAME=`echo $OPTARG | tr [:lower:] [:upper:]`;
		;;
		v  ) VERB='';
		;;
	esac
done
shift $(($OPTIND - 1 ));  ## remove the optional args if there were any

## Needed to check which DB type we're on.
. ${IM_SRC}/im/config/alta.conf  || \
	( echo -e "\n\${IM_SRC}/config/alta.conf file not found.\nCan't proceed!" && exit 1 )



## Make sure we got new value to set. (Skip if just getting)
if [ "$GET" != "1" ]; then
	if [ "$#" -ne 1 -o "$1" == "" ];then
		echo "Got no 'num' value argument!"
		usage
		exit 1
	else
		VALUE=$1
	fi
fi

## make sure we have a SEQuence NAME. Needed at all times 
if [ "$SEQNAME" == "" ];then
	 echo "Sequence name [-s X] argument missing!"
	usage
	exit 1; 
fi




## ------   do it   ------- ##
MSG=
if [ "$GET" == "1" ]; then
	## Get value.
	MSG="Getting $SEQNAME ..."
	SQL=`echo "select data from OpaqueMessage where orig = 'Reporter:${SEQNAME}:SEQ' and id = ${OUTBOUND}; quit ;" `

else
	## Set value.
	
	if [ "`_is_reporter_running`" -eq 1 ];then
		echo 'REPORTER IS STILL RUNNING!';
		echo 'You must shutdown reporter first in order to change these values!';
		exit 1;
	fi
	
	## When user enters a number, it is fine for Sybase as is.
	## But for Oracle we need to translate it in order to place in blob column.
	if [ "`echo "${IM_DATABASE_SCHEMA}" | tr [:lower:] [:upper:]`" == "ORACLE" ];then
		echo "(Adjusting value to Oracle format...)"
	    VALUE=`perl -e '$input = "'$1'"; $out = 0; for ($i = 0; $i < length($input); $i++) { $out *= 256; $out += ord(substr($input,$i,1)); }; printf("%x", $out)';`
	    echo "(... '$1' is now '$VALUE')"
	fi
	
	MSG="Setting $SEQNAME to $VALUE ..."
	SQL=`echo "update OpaqueMessage Set data = '$VALUE' where orig = 'Reporter:${SEQNAME}:SEQ' and id = ${OUTBOUND}; quit;"`
fi


if [ "$VERB" == "" ];then   echo $MSG; fi

echo $SQL | sqlminus $VERB




