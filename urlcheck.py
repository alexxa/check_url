#!/bin/python
#
# urlcheck.py -- Check files for invalid URLs.
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

import optparse, re, glob, os, mmap, requests

parser = optparse.OptionParser()

parser.add_option('-p', '--path',
    action="store", dest="path",
    help="Path to check, str. Default: %default", default="./")

parser.add_option('-e', '--exclude',
    action="store", dest="exclude",
    help="Path to exclude, list of str. Default: %default", default=['.git', 'vendor'])

parser.add_option('-t', '--fyle_type',
    action="store", dest="file_types",
    help="File types to look at, set of str. Default: %default", default=(".md", ".rst"))

options, args = parser.parse_args()

print 'Path to check:', options.path
print 'Path to exclude:', options.exclude
print 'Fyle types to look for', options.file_types

reg = re.compile("https?://[a-zA-Z0-9./?=_-]*")

#find desired files
files_list = []
for root, dirs, files in os.walk(options.path, topdown=True):
    if not any(options.path in root for options.path in options.exclude):
        for file in files:
            file_path = os.path.join(root,file)
            if file.endswith(options.file_types) and \
               os.path.getsize(file_path) > 0:
               files_list.append(file_path)

#check files for unique URLs
urlmap = {}
for file in files_list:
    f = open(file)
    #alleviate the possible memory problems in case of big files
    s = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
    f.close()
        
    find_url = reg.findall(s)

    for url in find_url:
        url = url.rstrip('?:!.,;')
        urlmap.setdefault(url,[]).append(file)
print "Number of unique URLs to check: ", len(urlmap)

#check for invalid URLs
invalid_url_counter = 0        
for url, files in urlmap.items():
    try:
        r = requests.get(url, timeout=5)
        if r.status_code != 200:
            print url, ' '.join([str(file) for file in files])
            invalid_url_counter += 1
    except requests.exceptions.RequestException:
        print url, ' '.join([str(file) for file in files]) 
        invalid_url_counter += 1

print "Number of invalid URLs: ", invalid_url_counter
