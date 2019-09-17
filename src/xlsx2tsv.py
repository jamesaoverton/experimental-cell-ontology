#!/usr/bin/env python3

import argparse, os, csv
from openpyxl import load_workbook

parser = argparse.ArgumentParser(
    description='Read TSV from Excel')
parser.add_argument('input',
    type=str,
    help='Excel file to read')
parser.add_argument('sheet',
    type=str,
    help='Sheet name to read')
args = parser.parse_args()

wb = load_workbook(args.input)
ws = wb[args.sheet]

colnum = 17
rownum = 0
for row in ws:
  rownum += 1
  values = []
  for cell in row:
    if cell.value is None:
      values.append('')
    else:
      values.append(str(cell.value))

  if args.sheet == 'human':
    if rownum == 1:
      values.insert(colnum, 'In Taxon')
    elif rownum == 2:
      values.insert(colnum, 'C %')
    else:
      values.insert(colnum, 'Homo sapiens')
  elif args.sheet == 'mouse':
    if rownum == 1:
      values.insert(colnum, 'In Taxon')
    elif rownum == 2:
      values.insert(colnum, 'C %')
    else:
      values.insert(colnum, 'Mus musculus')

  print('\t'.join(values))

