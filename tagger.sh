#!/bin/sh

# exit when any command fails
set -e

usage()
{
    echo "usage: tagger [[[-f file ] [-r include rating tag] [-l include location tag] [-w write to file (otherwise just report tags found)] [-o overwrite (don't make backup copy of photo)]  [-v verbose]] | [-h]]"
}



##### Main

ratingFound=
locationFound=
verbose=
overwriteOriginal=
filename=~/sysinfo_page.html
exiftoolPath="${BASH_SOURCE%/*}/Image-ExifTool-10.77/"
exiftool="$exifToolPath/exiftool"
logfile="${BASH_SOURCE%/*}/tagger-log-$(date).txt"

while [ "$1" != "" ]; do
    case $1 in
        -f | --file )           shift
                                filename=$1
                                ;;
        -r | --rating )    		getRating=1
                                ;;
        -l | --location )    	getLocation=1
                                ;;
        -w | --write )    		writeData=1
                                ;;
        -o | --overwrite )    	overwriteOriginal=1
                                ;;
        -v | --verbose )    	verbose=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done


seperator='----------------------------------------------------------------------'
echo $seperator
printf "Running tagger.sh script, start time $(date)\n"
echo $seperator

##### Check if exiftool is installed
if [ ! -d "$exiftoolPath" ]; then
	echo "Exiftool not found, downloading now"
	wget -O- https://www.sno.phy.queensu.ca/~phil/exiftool/Image-ExifTool-10.77.tar.gz | tar xz #&> /dev/null
	if [ "$?" == "0" ]; then
		echo "Exiftool successfully downloaded"
	else
		echo "Exiftool not downloaded, please download manually and retry."
		exit 1
	fi
fi


printf "Verifying image '$filename' exists...\n"
if [ -e "$filename" ]
then
    printf "\tFile found on drive!\n"
else
    printf "\tError: file not found!\n"
    exit
fi

imageId=$(psql -X -A -U postgres -d photo -t -c "SELECT id FROM photo_image WHERE path='${filename//\'/\'\'}';")

if [ -n "$imageId" ]; then
    printf "\tFound in PhotoStation DB with ID $imageId\n"
else
	printf "\tError: Image not found in PhotoStation DB, please make sure photo is indexed by PhotoStation!\n"
	exit
fi

if [ "$getLocation" = "1" ] || [ "$getRating" = "1" ]
then
	printf "Extracting file info from DB:\n"
fi

if [ "$getLocation" = "1" ]
then

	(( verbose == 1 )) && echo "Finding tags applied to image..."
	imageTagIds=$(psql -X -A -U postgres -d photo -t -c "SELECT label_id FROM photo_image_label WHERE image_id='$imageId';")

	if [ -n "$imageTagIds" ]; then
		locationTag='0'

		while read -r line; do
			imageTagName=$(psql -X -A -U postgres -d photo -t -c "SELECT name FROM photo_label WHERE id='$line';")
			imageTagCat=$(psql -X -A -U postgres -d photo -t -c "SELECT category FROM photo_label WHERE id='$line';")
		    
		    if [ "$imageTagCat" = "1" ]
		    then
		    	(( verbose == 1 )) && printf "\t$line - $imageTagName (location)\n"
		    	locationTag=$imageTagName
		    	locationFound=1
			else
				(( verbose == 1 )) && printf "\t$line - $imageTagName\n"
			fi

		done <<< "$imageTagIds"

		if [ "$locationFound" = "1" ]
		then
			printf "\tLocation tag: \t$locationTag\n"
		fi
	else
		printf "\tNo image tags found!\n"
	fi
fi

if [ "$getRating" = "1" ]
then
	imageRating=$(psql -X -A -U postgres -d photo -t -c "SELECT rating FROM photo_image WHERE path='${filename//\'/\'\'}';")
	ratingFound=1
	printf "\tRating tag: \t$imageRating\n"
fi

([ "$locationFound" = "1" ] || [ "$imageRating" != "0" ]) && dataToWrite=1 || dataToWrite=1


if [ "$writeData" = "1" ]
then
	if [ "$dataToWrite" = "1" ]
	then

		#(( verbose == 1 )) && echo "Checking current image data..."
		#(( verbose == 1 )) && $exiftool -s "$filename"

		args=()
		(( locationFound == 1 )) && args+=( '-xmp-xmp:SynoPhotoLocation='"$locationTag" )

		if [ "$ratingFound" = "1" ]
		then
		
			args+=( '-rating='"$imageRating" )

			#Windows depends on ratingpercent tag as well to show ratings in explorer / gallery, need to set this:
			case $imageRating in
			0)
			  args+=( '-ratingpercent=' )
			  ;;
			1)
			  args+=( '-ratingpercent=1' )
			  ;;
			2)
			  args+=( '-ratingpercent=25' )
			  ;;
			3)
			  args+=( '-ratingpercent=50' )
			  ;;
			4)
			  args+=( '-ratingpercent=75' )
			  ;;
		  	5)
			  args+=( '-ratingpercent=99' )
			  ;;
			esac
		fi

		args+=( '-F' ) #fix minor errors in metadata (otherwise we don't write if we detect problems)

		(( overwriteOriginal == 1 )) && args+=( '-overwrite_original' )

		exifToolCommand=("$exiftool" '-config' "${BASH_SOURCE%/*}/exiftool.config" "${args[@]}" "$filename")
		printf 'Write is set, writing info to image with call to ExifTool:\n'
		echo ${exifToolCommand[@]}

		"${exifToolCommand[@]}"

		#(( verbose == 1 )) && echo "Checking updated image data..."
		#(( verbose == 1 )) && $exiftool -s "$filename"

		(( verbose == 1 )) && echo "Fixing synology file permissions (ACL)..."
		synoacltool -enforce-inherit "$filename"

	else
		echo "No data to write to photo file."
	fi
else
	(( dataToWrite == 1 )) && echo "Specify -w to write found data to photo file."
fi

echo $seperator