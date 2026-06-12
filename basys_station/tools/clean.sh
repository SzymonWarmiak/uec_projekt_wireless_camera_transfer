#!/bin/bash
#
# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk
# Modified by: Szymon Warmiak, Grzegorz Twardosz
#
# Description:
# Remove untracked files from the project
# To work properly, a git repository in the project directory is required.
# Run from the project root directory.

git clean -fdX
