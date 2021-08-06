#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jul 12 11:18:15 2021

@author: simonyj
"""

from bids_validator import BIDSValidator
import glob 

bids_dir = '/home/simonyj/EEG_BIDS'

validator = BIDSValidator()

filepaths = glob.glob(f"{bids_dir}/**/*.*",recursive = True)

n_files = 0

for filepath in filepaths:
    if '.m' or '.py' not in filepath:
        file_path = filepath.split(bids_dir)[1]
        if not validator.is_bids(file_path):
            print(f"Found NON-BIDS compliant file path: {file_path}")
            n_files += 1
    
if n_files == 0:
    print("All files are BIDS compliant")
    
