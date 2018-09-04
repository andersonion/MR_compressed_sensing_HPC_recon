#!/bin/bash
# given symbolic link sets of directories inside this folder, 
# copy the specified set, to the new name.
if [ -z "$2"  ]; 
then 
    echo -n "$0 current_tag dest_tag overwrite, you forgot to specify ";
    if [ -z "$1" ]; then 
	echo "anything"; 
	else
	echo "a dest";fi;
    exit;
fi;

current_tag=$1;
dest_tag=$2;
overwrite=$3; # overwrite is a standin for mode. -1, check only, 0 do not over write, 1 overwrite
TEST_MODE="";#"echo"; # set to echo for test mode
if [ -z "$overwrite" ]; 
then overwrite=0;
else 
    overwrite=$(echo "$overwrite" | grep -cE "^1$|^([Yy]([eE][sS]$)?)$" );
fi;

pushd $PWD > /dev/null;
cd $(dirname $0);
update_list="";
for mexec in */ ;
do echo "--$mexec--";
    # internal vars,
    # cp is current path, from readlink on the executeable
    # dp is current path, from readlink on the dest_exec
    # when those are equal we know there is no work to do.
    if [ -e $mexec${current_tag} ]; 
    then cp=$(readlink $mexec${current_tag});
    else 
	echo "    has no $current_tag available.";
	continue;
    fi;
    if [ -e $mexec${dest_tag} ];
    then dp=$(readlink $mexec${dest_tag});
    else
	echo "    has no $current_tag available.";
	dp="${mexec}NOCURRENT";
    fi;
    if [ "$cp" = "$dp" ]; then
	echo -n "";
    else
	if [ ! -z "$dp" ];then
	    # dest exists, is defined, and is not same.
	    echo "$dest_tag, is not $current_tag.";
	    echo "    $dest_tag:$dp";
	    echo "    $current_tag:$cp";
	    if [ "$overwrite" -eq 1 ];then
		$TEST_MODE unlink ${mexec}${dest_tag};
	    else 
		continue;
	    fi;
	fi;
	update_list="$update_list $mexec";
    fi;
done

#echo "list:($update_list)";

for mexec in $update_list ;
do otag="${mexec}${dest_tag}";
    cp=$(readlink ${mexec}${current_tag});
    if [ ! -e $otag ];
    then $TEST_MODE ln -vs $cp $otag;
    fi;
done

popd > /dev/null; 
