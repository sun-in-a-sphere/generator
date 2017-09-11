#!/bin/bash
#
#
#     Skript for downloading 360° images from https://stereo-ssc.nascom.nasa.gov/browse_sphere/
#     and process them to a movie and project to a sphere
#    
#     The processed images are meant to be used and are tested with a laserbeamer and  a 180° fish eye lens. 
#     
#    
#     Configuration file sun-in-a-sphere.conf contains various adjustable settings.
#    
#     Authors: Lukas Musy & Mischa Nüesch
#     Organization: FHNW
# 
#

readonly conf="./sun-in-a-sphere.conf"
readonly URL="https://stereo-ssc.nascom.nasa.gov/browse_sphere/"

setup() {
    #go to current dir
    cd "$(dirname "$0")"

    #parse strings to date
    timeframe_start=$(get_date_from_str $timeframe_start)
    timeframe_end=$(get_date_from_str $timeframe_end)

    #test mode
    if [ $test_mode = true ]; then
        test_folder=sun_in_a_sphere_test
        mkdir -p $test_folder
        cd $test_folder
    
    else
        #create worker directory
        mkdir $pics_folder
        cd $pics_folder

    fi

}

#debug console output
debugging() {
    set -x
}

#enable logging
logging() {
    mkdir -p ./logs
    scriptname=$(echo $(basename "$0") | cut -f 1 -d '.')
    logfile="../logs/$(date +"%y-%m-%d-%H%M")_$scriptname.log"

    log() {
        echo "$1" >> $logfile
    }
}

config() {
    val=$(grep -E "^$1=" $conf 2>/dev/null || echo "$1=DEFAULT" | head -n 1 | cut -d '=' -f 2-)
    if [[ $val == DEFAULT ]]
    then
        case $1 in
            movie_name)
                echo -n movie_name=sun_in_a_sphere
                ;;
            timeframe_start)
                echo -n timeframe_start=2012-09-01
                ;;
            timeframe_end)
                echo -n timeframe_end=2012-10-24
                ;;
            wavelength)
                echo -n wavelength=304
                ;;
            contrast)
                echo -n contrast=60%
                ;;
            offset)
                echo -n offset=5
                ;;
            test_mode)
                echo -n test_mode=false
                ;;
            parallel)
                echo -n parallel=false
                ;;
            rotate)
                echo -n rotate=true
                ;;
            clean_afterwards)
                echo -n clean_afterwards=true
                ;;
            pics_folder)
                echo -n pics_folder=sun_in_a_sphere_images
                ;;
            debug)
                echo debug=false
                ;;
            dl)
                echo dl=true
                ;;
            open_output)
                echo open_output=true
                ;;
            cores)
                echo cores=4
                ;;
        esac
    else
        echo -n $val
    fi
}

init_config() {

    #get config values
    config_values="$(config movie_name)
        $(config timeframe_start)
        $(config timeframe_end)
        $(config wavelength)
        $(config contrast)
        $(config offset)
        $(config test_mode)
        $(config parallel)
        $(config rotate)
        $(config clean_afterwards)
        $(config pics_folder)
        $(config debug)
        $(config dl)
        $(config open_output)
        $(config cores)

        "
    eval $config_values

    echo "
    
        The Sun In A Sphere

        ****************************************************************************************************

        "
    if [ ! -f ./$conf ]; then
        echo $"


        No configuration file (sun-in-a-sphere.conf) could be found. 

        Do you wish to continue with the (recommended) default settings?

        Be aware that it takes some time. Running it over night is recommended. 
        
        Get some sleep.

        ****************************************************************************************************
        
        Settings:
        
        $config_values"
        select yn in "Yes" "No"; do
            case $yn in
                Yes ) break;;
                No ) exit;;
            esac
        done
    fi
    echo "

    ... starting movie creation with the following settings:

    $config_values

    ****************************************************************************************************"
    
}

get_date_from_str() {
    date -j -f "%Y-%m-%d" "$1" "+%s"
}

format_time(){
    echo $(printf '%dh:%dm:%ds\n' $(($1/3600)) $(($1%3600/60)) $(($1%60)))
}

color_correction() {
    echo $"\\( -page +0+$offset -clone 0 -background none -flatten -channel R -separate \\) \\( -clone 0 -channel G -separate \\) \\( -clone 0 -channel B -separate \\) -delete 0 -channel red,green,blue -combine "
}

polar_projection() {
    local angle=$1
    local contrast=$2
    echo "-virtual-pixel Black -distort Polar 0 -distort SRT $angle -level 0%,$contrast,0.5 "
}

clean_up() {
    if [ "$clean_afterwards" = true ]; then
        if [ $test_mode = false ]; then
            #remove pics folder
            cd .. && rm -r $pics_folder
            log "deleted temp pics folder"
        else
            rm ./$test_image
        fi
    fi
}

download() {
    #make function accessible from other shells
    export -f dl_job

    #loop through days in time range and download the images (async)
    local dl_i=$timeframe_start
    while [ "$dl_i" -le "$timeframe_end" ]; do
        dl_year=$(date -j -f "%s" $dl_i "+%Y")
        dl_month=$(date -j -f "%s" $dl_i "+%m")
        dl_day=$(date -j -f "%s" $dl_i "+%d")
        dl_path=$URL$dl_year/$dl_month/$dl_day/$wavelength/

        dl_files=$(wget -q -O - $dl_path |   grep -o '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//' -e 's/["'"'"']$//' | grep jpg)        

        for dl_file in ${dl_files} ; do
            # create dl job
            if [ $parallel = true ]; then
                sem -j 2 --id dl_$$ dl_job $dl_path$dl_file
            else 
                dl_job $dl_path$dl_file
                
            fi
        done
        dl_i=$(($dl_i+86400))

    done
}

dl_job() {
    wget -q -N $1
}

image_processing() {
    #init rotation variable
    local rotation_angle=0

    #make  accessible from other shells
    export -f ip_job
    export -f process_image
    export -f polar_projection
    export -f color_correction

     #loop through days in time range and process images
    ip_i=$timeframe_start
    while [ "$ip_i" -le "$timeframe_end" ]; do
        ip_year=$(date -j -f "%s" $ip_i "+%Y")
        ip_month=$(date -j -f "%s" $ip_i "+%m")
        ip_day=$(date -j -f "%s" $ip_i "+%d")

        ip_path=$URL$ip_year/$ip_month/$ip_day/$wavelength/

        #get all file names from html
        ip_files=$(wget -q -O - $ip_path |   grep -o '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//' -e 's/["'"'"']$//' | grep jpg)      
  
        for ip_file in ${ip_files} ; do
            log "processing file $file"
            if [ $parallel = true ]; then
                sem -j $cores --id $$ ip_job $ip_file $rotation_angle $contrast
            else
                ip_job $ip_file $rotation_angle
            fi

            if [ "$rotate" = true ]; then
                rotation_angle=$(($rotation_angle+1))
            fi
        done
        ip_i=$(($ip_i+86400))
    done    
}

ip_job() {
     #wait for file to be downloaded and process_image
    while true ;do 
        #check if file readable, exists and not still opened by wget
        if test -r "$1" -a -f "$1" && ! [[ `lsof -c wget | grep $1` ]] ; then
            process_image $1 $2 $3
            # flock .lock_$1 $(eval $(process_image $1 $2))
            break
        fi
    done

}

process_image() {
        local img=$(echo $(basename $1) | cut -f 1 -d '.')
        local ext=$(echo $(basename $1) | cut -f 2 -d '.')    

        local dimensions=$(identify -format "%[fx:w]x%[fx:h]" $1)
        local h=$(echo $dimensions | cut -f 2 -d 'x')
        local w=$(echo $dimensions | cut -f 1 -d 'x')

        #get brighness to detect images with missing data
        local brightness=$(convert $1 -colorspace Gray -format "%[fx:quantumrange*image.mean]" info:)
        local brightness_int="$(echo $brightness | cut -f 1 -d '.')"

        local angle=$2
        local contrast=$3

        #filter out images brightness not in range 30000-40000 (containing missing data)
        if [ $brightness_int -gt 30000 -a $brightness_int -lt 40000 ]; then
            local cmd="convert  $1 "
            local cmd+=$(color_correction)

            #transform azimuthal equal distance and rotate
            local cmd+=$(polar_projection $angle $contrast)
            local cmd+=$(color_correction)
            # fi 
            local cmd+="$1"
        
            #execute image processing command
            eval $"$cmd"
        else 
            #delete
            rm "./$1"
        fi 
} 


run() {
    if [ $test_mode = false ]; then
        
        if [ "$dl" = true ]; then
            #run downloading job
            download "$@" &
        fi

        #some headstart for the dl job
        while [ $(ls -1 | wc -l) -lt 3 ]; do 
            sleep 1
        done

        image_processing "$@"

        #wait for jobs to finish
        if [ $parallel = true ]; then
            sem --id $$ --wait
        else 
            wait
        fi

        create_output "$@"

    else
        #test mode (single image processing)
        test_image_path=""$URL"2012/10/19/304/"
        test_image="20121019_005615_304.jpg"
        if [ ! -f $test_image ]; then
            wget -q $test_image_path$test_image
        fi

        echo "test tes :"$contrast

        process_image $test_image 0 $contrast       
    fi 

    clean_up "$@"
    

    if [ "$open_output" = true ]; then
        open_projection "$@"
    fi
}

create_output() {
    mencoder "mf://*.jpg" -o "../$movie_name.avi" -speed 0.5 -really-quiet -ovc lavc -lavcopts vcodec=mjpeg
}

open_projection() {
    #set output file
    if [ $test_mode = true ]; then
        echo $(ls -la .)
        output="./trans_$test_image"
        output_type="Image"
    else
        output="./$movie_name.avi"
        output_type="Video"
    fi

    if [ -f ../$output ]; then
        #get platform uname
        plattform=$(uname)

        #open output
        case $plattform in 
            Linux)
                xdg_open $output
                ;;
            Darwin)
                open $output
                ;;
        esac
    else
        echo "$output_type could not be created. See log file for more infos or enable debug mode and run again to find out."
    fi
}

main() {
    #time tracking
    start=`date +%s`
    logging "$@"

    #initialize configuration
    init_config "$@"

    if [ "$debug" = true ]; then
        debugging "$@"
    fi

    setup "$@"
    run "$@"

    end=`date +%s`
    runtime=$((end-start))
    echo "Sun in a Sphere terminated in $(format_time $runtime)"

    #abort other jobs too when interrupted (ctrl-c)
    trap "pkill -P $$" SIGINT
    trap clean_up "$@" SIGTERM EXIT
}
main "$@"




