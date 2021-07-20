#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jul 12 11:56:38 2021

@author: simonyj
"""

import json 
import glob 
import os

bids_dir = '/home/simonyj/EEG_BIDS'

old_key_substring = 'Int_'
new_key_substring = ''

filepaths = glob.glob(f"{bids_dir}/**/*.json",recursive = True)


for filepath in filepaths:
    with open(filepath,encoding = "ISO-8859-1") as f:
        json_str1 = str(json.load(f))
        json_str2 = json_str1.replace(old_key_substring,new_key_substring)
        json_str3 = json_str2.replace("'",'"')
        json_str4 = f"{json_str3}"
        json_dict = json.loads(json_str4)
    
    os.remove(filepath)
    
    out_file = open(filepath, "w")
    json.dump(json_dict, out_file, indent = 6)
    out_file.close()

print(f"Removed integer keyword '{old_key_substring}' from .json file keys.")