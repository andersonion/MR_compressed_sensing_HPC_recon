#!/bin/bash
$(dirname $0)/tag_execs.sh latest stable
exit;
# prototype code below.
for mexec in */ ;
do echo "--$mexec--";
    # st -> stable
    # lp -> latest path
    if [ -e $mexec/stable ];
    then st=$(readlink $mexec/stable);
    else
	st="NO_STABLE";
    fi;
    if [ -e $mexec/latest ]; 
    then lp=$(readlink $mexec/latest);
    fi;
    if [ "$lp" != "$st" ];
    then echo "Latest, is not stable, you can change that using the set_latest_to_stable.bash script here.";
	echo $st
	echo $lp 
    fi;
    unset st lp
done
