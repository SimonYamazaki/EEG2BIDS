#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jul 12 11:56:38 2021

@author: simonyj
"""

import json 
import glob 
import os
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("bids_dir", help="root bids directory")
args = parser.parse_args()

bids_dir = args.bids_dir

print(bids_dir)

#%%

bids_dir = '/home/simonyj/TEST_MMN_BIDS'

old_key_substring = 'Int_'
new_key_substring = ''

filepaths = glob.glob(f"{bids_dir}/**/*.json",recursive = True)

with open(filepaths[1],encoding = "ISO-8859-1") as f:
        json_dict = json.load(f)

keys = []

def recursive_items(dictionary,keys):
    for key, value in dictionary.items():
        keys.append(key)
        if isinstance(value,type(dict)):
            yield from recursive_items(value,keys)
        else:
            yield (key, value)

for key, value in recursive_items(json_dict,keys):
    continue
    

indices = [i for i, s in enumerate(keys) if old_key_substring in s]
indices = [i for i, s in enumerate(keys) if 'EXG' in s]


kd = { 'Int_': ''}
    
def replace_keys(old_dict):
    new_dict = { }
    for key in old_dict.keys():
        new_key = old_dict.get(key, key)
        if isinstance(old_dict[key], type(dict)):
            new_dict[new_key] = replace_keys(old_dict[key])
        else:
            if 'Int_' in key:
                key = key[4:]
            new_dict[new_key] = old_dict[key]
    return new_dict


nd = replace_keys(json_dict)



#from stachoverflow 

od = { 1: { 2: { 3: None }}}
kd = { 1: 'x', 2: 'y', 3: 'z' }

def replace_keys(old_dict, key_dict):
    new_dict = { }
    for key in old_dict.keys():
        new_key = key_dict.get(key, key)
        if isinstance(old_dict[key], dict):
            new_dict[new_key] = replace_keys(old_dict[key], key_dict)
        else:
            new_dict[new_key] = old_dict[key]
    return new_dict

nd = replace_keys(od, kd)
print nd
outputs:

{'x': {'y': {'z': None}}}


#%%

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