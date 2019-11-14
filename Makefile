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
	curl -L -o $@ https://github.com/ontodev/robot/releases/download/v1.4.3/robot.jar


### Ontology Source Tables

tables = dependencies general human mouse
source_files = $(foreach o,$(tables),ontology/$(o).tsv)
templates = $(foreach i,$(source_files),--template $(i))

### Tables
#
# These tables are stored in Google Sheets, and downloaded as TSV files.

build/XCL_Template.xlsx: | build
	curl -L -o $@ "https://docs.google.com/spreadsheets/d/1Ja1IYLWygg3k-beGPRg_uza_8-FPBLzF90WbHkbCi4Q/export?format=xlsx"

ontology/%.tsv: src/xlsx2tsv.py build/XCL_Template.xlsx
	python3 $^ $* > $@

build/cl.owl:
	curl -L -o $@ "http://purl.obolibrary.org/obo/cl.owl"

build/ancestors.owl: build/cl.owl | build/robot.jar
	$(ROBOT) extract \
	--method STAR \
	--input $< \
	--term "CL:0000542" \
	--output $@

# TODO: Fix XCL prefix
xcl.owl: ontology/metadata.ttl $(source_files) | build/robot.jar
	$(ROBOT) template \
	--prefix "XCL: http://example.com/XCL_" \
	--input $< \
	$(templates) \
	--output $@

.PHONY: update
update: clean-data xcl.owl

.PHONY: clean-data
clean-data:
	rm -f xcl.owl build/XCL_Template.xlsx $(source_files)

.PHONY: clean
clean:
	rm -rf build
	rm -f xcl.owl

.PHONY: clobber
clobber: clean
	rm -f $(source_files)

.PHONY: all
all: xcl.owl

