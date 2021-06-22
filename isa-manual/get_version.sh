#!/bin/bash

# Generate a \specrev TeX command based on git describe.
echo '\newcommand{\specrev}{\mbox{'"$(git describe --tags --match 'v*.*')"'}}'

