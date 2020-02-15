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

### Workflow
#
# 1. Edit the [Google Sheet](https://docs.google.com/spreadsheets/d/1Ja1IYLWygg3k-beGPRg_uza_8-FPBLzF90WbHkbCi4Q)
# 2. Run [Update](update) to fetch the latest data, validate it, and rebuild
# 3. View the validation result tables:
#     - [General](build/general.html) (not species-specific) cell types ([general.xlsx](build/general.xlsx))
#     - [Human](build/human.html) cell types ([human.xlsx](build/human.xlsx))
#     - [Mouse](build/mouse.html) cell types ([general.xlsx](build/general.xlsx))
# 4. If the tables were valid, then view the resulting trees:
#     - [General](build/xcl.html) tree ([xcl.owl](xcl.owl))
#     - [Human](build/human-tree.html) tree ([human-tree.owl](build/human-tree.owl))
#     - [Mouse](build/mouse-tree.html) tree ([mouse-tree.owl](build/mouse-tree.owl))

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

GENERAL := build/general.html build/general.xlsx
$(GENERAL): xcl.owl build/general.tsv | build/robot.jar
	$(ROBOT) validate \
	--input $< \
	--table $(word 2,$^) \
	--format $(subst .,,$(suffix $(notdir $@))) \
	--standalone true \
	--output-dir $(dir $@)

HUMAN := build/human.html build/human.xlsx
$(HUMAN): xcl.owl build/human.tsv | build/robot.jar
	$(ROBOT) validate \
	--input $< \
	--table $(word 2,$^) \
	--format $(subst .,,$(suffix $(notdir $@))) \
	--standalone true \
	--output-dir $(dir $@)

MOUSE := build/mouse.html build/mouse.xlsx
$(MOUSE): xcl.owl build/mouse.tsv | build/robot.jar
	$(ROBOT) validate \
	--input $< \
	--table $(word 2,$^) \
	--format $(subst .,,$(suffix $(notdir $@))) \
	--standalone true \
	--output-dir $(dir $@)

build/human-tree.owl: xcl.owl | build/robot.jar
	$(ROBOT) remove \
	--input $^ \
	--term 'http://example.com/XCL_M1' \
	--select 'self descendants' \
	remove \
	--term 'http://example.com/XCL_H1' \
	--term 'http://example.com/XCL_H2' \
	reduce \
	--output $@

build/mouse-tree.owl: xcl.owl | build/robot.jar
	$(ROBOT) remove \
	--input $^ \
	--term 'http://example.com/XCL_H1' \
	--select 'self descendants' \
	remove \
	--term 'http://example.com/XCL_M1' \
	--term 'http://example.com/XCL_M2' \
	reduce \
	--output $@

build/%-tree.html: build/%-tree.owl | build/robot-tree.jar
	java -jar build/robot-tree.jar tree \
	--input $< \
	--tree $@
	mv $@ $@.tmp
	sed "s/params.get('text')/params.get('text') || 'cell'/" $@.tmp > $@
	rm $@.tmp

build/xcl.html: xcl.owl | build/robot-tree.jar
	java -jar build/robot-tree.jar tree \
	--input $< \
	--tree $@
	mv $@ $@.tmp
	sed "s/params.get('text')/params.get('text') || 'cell'/" $@.tmp > $@
	rm $@.tmp

TREES := xcl.owl build/xcl.html build/human-tree.owl build/human-tree.html build/mouse-tree.owl build/mouse-tree.html

.PHONY: update
update:
	rm -rf $(GENERAL) $(HUMAN) $(MOUSE) $(TREES)
	make $(GENERAL) $(HUMAN) $(MOUSE) $(TREES)


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

build/robot-tree.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/tree-view/lastSuccessfulBuild/artifact/bin/robot.jar


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

build/%.tsv: ontology/%.tsv
	sed '/LABEL/d' $^ | grep "\S" > $@

build/cl.owl:
	curl -L -o $@ "http://purl.obolibrary.org/obo/cl.owl"

build/ancestors.owl: build/cl.owl xcl.owl | build/robot.jar
	$(ROBOT) extract \
	--method STAR \
	--input $< \
	--term "CL:0000542" \
	merge \
	--input $(word 2,$^) \
	--output $@

# TODO: Fix XCL prefix
xcl.owl: ontology/metadata.ttl $(source_files) | build/robot.jar
	$(ROBOT) template \
	--prefix "XCL: http://example.com/XCL_" \
	--input $< \
	$(templates) \
	reason --output $@

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
