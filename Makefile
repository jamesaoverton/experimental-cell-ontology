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
# 1. Edit the [Google Sheet](https://docs.google.com/spreadsheets/d/1U-NwYVT624ve8zNZeNU0sx9woFvVWgRp_FZt1oALkGQ)
# 2. Run [Update](update) to fetch the latest data, validate it, and rebuild
# 3. View the validation result tables:
#     - [General](build/general.html) (not species-specific) cell types ([general.xlsx](build/general.xlsx))
# 4. If the tables were valid, then view the resulting trees:
#     - [General](build/xcl.html) tree ([xcl.owl](xcl.owl))
# 5. [OBO Taxonomy](build/obo-taxonomy-tree.html) ([obo-taxonomy.owl](build/obo-taxonomy.owl))

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
$(GENERAL): xcl.owl build/general.tsv | build/robot-validate.jar
	java -jar build/robot-validate.jar validate \
	--input $< \
	--table $(word 2,$^) \
	--format $(subst .,,$(suffix $(notdir $@))) \
	--standalone true \
	--output-dir $(dir $@)

HUMAN := build/human.html build/human.xlsx
$(HUMAN): xcl.owl build/human.tsv | build/robot-validate.jar
	java -jar build/robot-validate.jar validate \
	--input $< \
	--table $(word 2,$^) \
	--format $(subst .,,$(suffix $(notdir $@))) \
	--standalone true \
	--output-dir $(dir $@)

MOUSE := build/mouse.html build/mouse.xlsx
$(MOUSE): xcl.owl build/mouse.tsv | build/robot-validate.jar
	java -jar build/robot-validate.jar validate \
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

TREES := xcl.owl build/xcl.html

.PHONY: update
update:
	rm -rf $(GENERAL) $(TREES)
	make $(GENERAL) $(TREES)


### Set Up

build:
	mkdir -p $@

ontology:
	mkdir -p $@


### ROBOT
#
# We use the official development version of ROBOT for most things.

build/robot.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/master/lastSuccessfulBuild/artifact/bin/robot.jar

build/robot-validate.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/validate/lastSuccessfulBuild/artifact/bin/robot.jar

build/robot-tree.jar: | build
	curl -L -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/tree-view/lastSuccessfulBuild/artifact/bin/robot.jar

build/robot-rdfxml.jar: | build
	curl -Lk -o $@ https://build.obolibrary.io/job/ontodev/job/robot/job/mireot-rdfxml/lastSuccessfulBuild/artifact/bin/robot.jar


### Ontology Source Tables

tables = dependencies general
source_files = $(foreach o,$(tables),ontology/$(o).tsv)
templates = $(foreach i,$(source_files),--template $(i))

### Tables
#
# These tables are stored in Google Sheets, and downloaded as TSV files.

build/XCL_Template.xlsx: | build
	curl -L -o $@ "https://docs.google.com/spreadsheets/d/1U-NwYVT624ve8zNZeNU0sx9woFvVWgRp_FZt1oALkGQ/export?format=xlsx"

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
	reason --reasoner HermiT --output $@


### OBO Taxonomy Tree

build/obo-taxonomy.csv: in-taxon.rq | build
	curl -o $@ -X POST -F format=text/csv -F query=@$< 'http://sparql.hegroup.org/sparql/'

build/obo-taxonomy.txt: build/obo-taxonomy.csv
	sed /merged.PR/d $< | tail -n+2 | cut -d, -f3 | grep NCBITaxon \
	| sed s/\"//g | sed s!http://purl.obolibrary.org/obo/NCBITaxon_!NCBITaxon:! > $@
	echo 'NCBITaxon:33090' >> $@
	echo 'NCBITaxon:33208' >> $@
	echo 'NCBITaxon:4751' >> $@
	mv $@ $@.tmp
	sort $@.tmp | uniq > $@
	rm $@.tmp

build/ncbitaxon.owl.gz: | build
	curl -L http://purl.obolibrary.org/obo/ncbitaxon.owl | gzip > $@

build/obo-taxonomy.owl: build/ncbitaxon.owl.gz build/obo-taxonomy.txt | build/robot-rdfxml.jar
	java -jar build/robot-rdfxml.jar extract \
	--method rdfxml \
	--input $< \
	--term-file $(word 2,$^) \
	collapse \
	--precious-terms $(word 2,$^) \
	--output $@

build/obo-taxonomy.tsv: build/obo-taxonomy.owl build/obo-taxonomy.txt | build/robot.jar
	$(ROBOT) filter \
	--input $< \
	--term-file $(word 2,$^) \
	--select annotations \
	export \
	--header "ID|LABEL" \
	--export $@

build/obo-taxonomy-tree.html: build/obo-taxonomy.owl | build/robot-tree.jar
	java -jar build/robot-tree.jar tree \
	--input $< \
	--tree $@


### General Tasks

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
