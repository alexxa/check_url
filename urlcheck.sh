#!/bin/bash
#
# urlcheck.sh -- Check files for invalid URLs.
#
# Copyright (c) 2018 Irina Gulina
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#Functions
display_help() {
cat <<-END
This script looks for invalid URLs.
Usage:
------
   -h
     Display this help
   -p
     A path to look for URLs.
   -I
     A path to exclude from searching URLs.
     A string separated by commas without spaces.     
   -i
     A path to a file with ignored URLs.
     Default: ./ignore_url.yml. If a file doesn't exist,
     all found URLs are checked.
   -a
     Ignore a file with ignored URLs, i.e. check all URLs.
   -t
     File types to check for URLs.
     A string separated by commas without spaces.
     Default: *.md,*rst
   -q
     Quite. Default: false.
   -v
     Verbose. Default: false.
END
} 

#Default Values

# Path to exclude from searching URLs.
# A string separated by commas without spaces.
exclude_path="vendor,./vendor"

# File types to check for URLs.
# A string separated by commas without spaces.
file_types="*.md,*.rst"

# A path to a file with ignored URLs.
ignore_urls="./ignore_url.yml"

# A path to look for URLs.
check_path="."

# Regex to find URL
url_regex="https?://[a-zA-Z0-9./?=_-]*"
#url_regex="(^|[^\`])\bhttps?://[a-zA-Z0-9./?=_-]*"

# Not be verbose by default
verbose=false

# Not be quite by default
quite=false

# Default logfile name
logfile=urlcheck.log

# Parse arguments
while getopts ":p:i:t:I:haq:" opt; do
    case $opt in
        h)
            display_help && exit 0 
            ;;
        a)
            ignore_urls=""
            ;;
        q)
            quite=true
            ;;
        p)
            check_path="${OPTARG}"
            ;;
        i)
            ignore_urls="${OPTARG}"
            ;;
        I)
            exclude_path="${OPTARG}"
            ;;
        t)
            file_types="${OPTARG}"
            ;;
        \?)
            echo "Invalid option: -${OPTARG}"
            ;;
        :)
            echo "Option -${OPTARG} requires an argument.  Use -h for more details."
    esac
done


#Find URLs

input=$(eval grep -EHori --exclude-dir={$exclude_path} \
        --include={$file_types} \'$url_regex\' "$check_path" | sed 's/:[^a-z]/:/g') 

#Build a dictionary of unique URLs 
declare -A urlmap

i=1
sp="/-\|"
echo -n ' '

for entry in $(echo -e "$input"); do
    
    $quite && printf "\rCalculating an array of URLs  \b${sp:i++%${#sp}:1}"
    
    page=$(echo $entry | cut -d ':' -f 1)
    url=$(echo $entry | cut -d ':' -f 2- | sed -e 's/[.]*$//')
 
    if [ -z "${urlmap[$url]}" ]; then
        urlmap[$url]=$page
    else
        urlmap[$url]=${urlmap[$url]},\ $page
    fi
done 

#Print a number of unique URLs to check
echo -e "\rA number of unique URLs to check: ${#urlmap[@]}"

progress_index=0
invalid_url_index=0

for key in "${!urlmap[@]}"; do
    #Check curl code of URL header
    if ! curl -sIf -m 5 --retry 1 -o /dev/null "$key" || \
       ! curl -sIfL -m 5 --retry 1 -o /dev/null "$key"; then
      #Record not ignored URL
      if [ -z "$ignore_urls" -o ! -f "$ignore_urls" ] || \
           ! grep -Fxq "$key" "$ignore_urls" ; then
        
        echo "Error: $key in ${urlmap[$key]}"
        invalid_url_index=$((invalid_url_index+1))
      fi
    fi
    #Print a percent of checked URLs
    $quite && echo -ne "$(expr $progress_index "*" 100 "/" ${#urlmap[@]})"'%\r'
    progress_index=$((progress_index+1))
done

#Print a number of found invalid URLs
if [ "$invalid_url_index" != 0 ]; then
  echo "A number of invalid URLs: $invalid_url_index"
else
  echo "No invalid URL found."
fi
