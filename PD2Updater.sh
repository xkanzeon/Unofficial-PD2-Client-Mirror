#!/bin/bash

# Run this file from the ProjectD2 folder

server="Live" # Live or Beta

launcher="https://storage.googleapis.com/storage/v1/b/pd2-launcher-update/o"
client="https://storage.googleapis.com/storage/v1/b/pd2-client-files/o"
newclient="https://pd2-client-files.projectdiablo2.com"

if [[ $server == "Beta" ]]; then
    $client="https://storage.googleapis.com/storage/v1/b/pd2-beta-client-files/o"
    $newclient="https://pd2-beta-client-files.projectdiablo2.com"
fi

if [[ ! -d "$server" ]]; then
    mkdir "$server"
fi

download_main_files() {
    server=$1
    filehost=$2

    md5=$3
    filename=$4

    if [[ $5 ]]; then
        filename="$4 $5"
    fi

    if $(echo "$3  ./$server/$filename" | md5sum -c --status); then
        echo "$filename already downloaded. Skipping..."
    else
        if [[ $filename == *"/"* ]]; then
            mkdir -p "$server/${filename%/*}"
        fi
        echo "Downloading $filename..."
        curl --create-dirs "$filehost/${filename// /"%20"}" -o "$server/$filename"
        echo "Done"
    fi
    if [[ ! $(echo "$3 $filename" | md5sum -c --status) ]]; then
        echo "Installing $filename..."
        if [[ $filename == *"/"* ]]; then
            mkdir -p "${filename%/*}"
        fi
        cp "$server/$filename" "$filename"
    fi

}

download_google_files() {
    server=$1

    file=$(curl -s $2)

    filename=$(echo $file | jq -r '.name')
    fileurl=$(echo $file | jq -r '.mediaLink')
    filemodtime=$(echo $file | jq '.updated')
    filesize=$(echo $file | jq '.size')


    if [[ $(date -d ${filemodtime:1:19} +%s) -le $(date -r "$server/$filename" +%s) ]]; then
        echo "$filename already downloaded. Skipping..."
    else
        if [[ $filename == *"/"* ]]; then
            mkdir -p "$server/${filename%/*}"
        fi
        echo "Downloading $filename..."
        curl --create-dirs $fileurl -o "$server/$filename"
        echo "Done"
    fi
    if [[ $(date -r "$filename" +%s) -le $(date -r "$server/$filename" +%s) ]]; then
        echo "Installing $filename..."
        if [[ $filename == *"/"* ]]; then
            mkdir -p "${filename%/*}"
        fi
        cp "$server/$filename" "$filename"
    fi

}

echo "    Downloading launcher files..."
curl "$launcher" | jq '.items'[] | jq '.selfLink' | xargs -I@ bash -c "$(declare -f download_google_files) ; download_google_files $server @"
echo "    downloading main client files..."
curl "$newclient/metadata.json" | jq '.checksum'.[] | xargs -I@ bash -c "$(declare -f download_main_files) ; download_main_files $server $newclient @"
curl "$newclient/metadata.json" -o "local_metadata.json"
echo "    Downloading optional client files..."
curl "$client" | jq '.items'[] | jq '.selfLink' | xargs -I@ bash -c "$(declare -f download_google_files) ; download_google_files $server @"

