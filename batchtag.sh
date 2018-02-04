#!/bin/sh

tagger="${BASH_SOURCE%/*}/tagger.sh"
seperator='----------------------------------------------------------------------'

usage()
{
    echo "usage: batchtag [[[-d directory ] [-r include rating tag] [-l include location tag] [-w write to file (otherwise just report tags found)] [-o overwrite (don't make backup copy of photo)]  [-v verbose]] | [-h]]"
}

while [ "$1" != "" ]; do
    case $1 in
        -d | --directory )      shift
                                directory=$1
                                ;;
        -r | --rating )			getRating=1
								;;
		-l | --location )		getLocation=1
								;;
		-v | --verbose )		verbose=1
								;;
		-w | --write )			writeData=1
								;;
		-o | --overwrite )		overwriteOriginal=1
								;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

#echo $directory
	
args=()
(( getRating == 1 )) && args+=( '-r' )
(( getLocation == 1 )) && args+=( '-l' )
(( verbose == 1 )) && args+=( '-v' )
(( writeData == 1)) && args+=( '-w' )
(( overwriteOriginal == 1)) && args+=( '-o' )

taggerCommand=("$tagger" "${args[@]}" '-f' )

#echo ${taggerCommand[@]}



echo $seperator
printf 'Running batchtag.sh script, start time: %(%d/%m/%Y  %I:%M:%S %P)T\n'
echo $seperator


time find "$directory" -iname "*.jpg" -not -path "*eaDir*" -not -path "*#recycle*" -exec ${taggerCommand[@]} "{}" \;