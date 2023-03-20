// generated by codegen/codegen.py
import codeql.swift.elements
import TestUtils

from File x, string getName, string isSuccessfullyExtracted
where
  toBeTested(x) and
  not x.isUnknown() and
  getName = x.getName() and
  if x.isSuccessfullyExtracted()
  then isSuccessfullyExtracted = "yes"
  else isSuccessfullyExtracted = "no"
select x, x.getPrimaryQlClasses(), "getName:", getName, "isSuccessfullyExtracted:",
  isSuccessfullyExtracted
