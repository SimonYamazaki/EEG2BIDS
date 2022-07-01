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
from itertools import compress

parser = argparse.ArgumentParser()
parser.add_argument("--bids_dir", help="root bids directory")
parser.add_argument("--script_name", help="script name without extension")

args = parser.parse_args()

bids_dir = args.bids_dir
script = args.script_name

print(bids_dir)

#%%

#bids_dir = '/mrhome/simonyj/JULY_VIA11_EEG_BIDS'

#script = "EEG2BIDS_MMN"

filepath = glob.glob(f"{bids_dir}/cluster_submissions/*{script}*.txt")[0]


with open(filepath) as f:
    lines = f.readlines()

#find all lines with warning
warn_idx = ["WARNING:" in l for l in lines] 
warn_lines = list(compress(lines, warn_idx))


#find line where the bids validator starts 
bidsval_idx = [n for n,l in enumerate(lines) if "#####  BIDS VALIDATION OUTPUT  #####" in l] 


#copy the warnings above where the bids validator starts 
for wl in warn_lines:
    lines.insert(bidsval_idx[0]-1,f"{wl}")

lines.insert(bidsval_idx[0]-1,"ALL WARNINGS \n \n")


with open(filepath, 'w') as f:
    f.writelines(lines)
