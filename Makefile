### Experimental Cell Ontology Makefile
#
# James A. Overton <james@overton.ca>
#
# This file is used to build an experimental version
# of the Cell Ontology, with species-specific cell types.
# Usually you want to run:
#
#     make clean all
#
# Requirements:
#
# - GNU Make
# - ROBOT <http://github.com/ontodev/robot>


### Configuration
#
# These are standard options to make Make sane:
# <http://clarkgrubb.com/makefile-style-guide#toc2>

MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:
.SECONDARY:

OBO = http://purl.obolibrary.org/obo
LIB = lib
ROBOT := java -jar build/robot.jar


### Set Up

build:
	mkdir -p $@

ontology:
	mkdir -p $@


### ROBOT
#
# We use the official development version of ROBOT for most things.

build/robot.jar: | build
	curl -L -o $@ https://github.com/ontodev/robot/releases/download/v1.4.1/robot.jar


### Ontology Source Tables

tables = imports cells
source_files = $(foreach o,$(tables),ontology/$(o).tsv)
templates = $(foreach i,$(source_files),--template $(i))

### Tables
#
# These tables are stored in Google Sheets, and downloaded as TSV files.

ontology/imports.tsv: | ontology
	curl -L -o $@ "https://docs.google.com/spreadsheets/d/1IWWyvZorh3vR_BocJh3pzWe4EcYB2HPai2MWckvDJ-A/export?format=tsv&id=1IWWyvZorh3vR_BocJh3pzWe4EcYB2HPai2MWckvDJ-A&gid=0"

ontology/cells.tsv: | ontology
	curl -L -o $@ "https://docs.google.com/spreadsheets/d/1IWWyvZorh3vR_BocJh3pzWe4EcYB2HPai2MWckvDJ-A/export?format=tsv&id=1IWWyvZorh3vR_BocJh3pzWe4EcYB2HPai2MWckvDJ-A&gid=691605019"

.PHONY: update-tsv
update-tsv: ontology/imports.tsv ontology/cells.tsv


# TODO: Fix XCL prefix
xcl.owl: $(source_files) | build/robot.jar
	$(ROBOT) template \
		--prefix "XCL: http://example.com/XCL_" \
	$(templates) \
	--output $@


.PHONY: clean
clean:
	rm -rf build
	rm -f xcl.owl

.PHONY: clobber
clobber: clean
	rm -f $(source_files)

.PHONY: all
all: xcl.owl

