#!/usr/bin/env python
# Copyright 2014 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Tests for enum_preprocess.py.

This test suite containss various tests for the C++ -> Java enum generator.
"""

import collections
import unittest
from java_cpp_enum import EnumDefinition, GenerateOutput, HeaderParser

class TestPreprocess(unittest.TestCase):
  def testOutput(self):
    definition = EnumDefinition(class_name='ClassName',
                                class_package='some.package',
                                entries=[('E1', 1), ('E2', '2 << 2')])
    output = GenerateOutput('path/to/file', definition)
    expected = """
// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file is autogenerated by
//     build/android/gyp/java_cpp_enum_tests.py
// From
//     path/to/file

package some.package;

public class ClassName {
  public static final int E1 = 1;
  public static final int E2 = 2 << 2;
}
"""
    self.assertEqual(expected, output)

  def testParseSimpleEnum(self):
    test_data = """
      // GENERATED_JAVA_ENUM_PACKAGE: test.namespace
      enum EnumName {
        VALUE_ZERO,
        VALUE_ONE,
      };
    """.split('\n')
    definitions = HeaderParser(test_data).ParseDefinitions()
    self.assertEqual(1, len(definitions))
    definition = definitions[0]
    self.assertEqual('EnumName', definition.class_name)
    self.assertEqual('test.namespace', definition.class_package)
    self.assertEqual(collections.OrderedDict([('VALUE_ZERO', 0),
                                              ('VALUE_ONE', 1)]),
                     definition.entries)

  def testParseTwoEnums(self):
    test_data = """
      // GENERATED_JAVA_ENUM_PACKAGE: test.namespace
      enum EnumOne {
        ENUM_ONE_A = 1,
        // Comment there
        ENUM_ONE_B = A,
      };

      enum EnumIgnore {
        C, D, E
      };

      // GENERATED_JAVA_ENUM_PACKAGE: other.package
      // GENERATED_JAVA_PREFIX_TO_STRIP: P_
      enum EnumTwo {
        P_A,
        P_B
      };
    """.split('\n')
    definitions = HeaderParser(test_data).ParseDefinitions()
    self.assertEqual(2, len(definitions))
    definition = definitions[0]
    self.assertEqual('EnumOne', definition.class_name)
    self.assertEqual('test.namespace', definition.class_package)
    self.assertEqual(collections.OrderedDict([('A', '1'),
                                              ('B', 'A')]),
                     definition.entries)

    definition = definitions[1]
    self.assertEqual('EnumTwo', definition.class_name)
    self.assertEqual('other.package', definition.class_package)
    self.assertEqual(collections.OrderedDict([('A', 0),
                                              ('B', 1)]),
                     definition.entries)

  def testEnumValueAssignmentNoneDefined(self):
    definition = EnumDefinition('c', 'p', [])
    definition.AppendEntry('A', None)
    definition.AppendEntry('B', None)
    definition.AppendEntry('C', None)
    definition.Finalize()
    self.assertEqual(collections.OrderedDict([('A', 0),
                                              ('B', 1),
                                              ('C', 2)]),
                     definition.entries)

  def testEnumValueAssignmentAllDefined(self):
    definition = EnumDefinition('c', 'p', [])
    definition.AppendEntry('A', '1')
    definition.AppendEntry('B', '2')
    definition.AppendEntry('C', '3')
    definition.Finalize()
    self.assertEqual(collections.OrderedDict([('A', '1'),
                                              ('B', '2'),
                                              ('C', '3')]),
                     definition.entries)

  def testEnumValueAssignmentReferences(self):
    definition = EnumDefinition('c', 'p', [])
    definition.AppendEntry('A', None)
    definition.AppendEntry('B', 'A')
    definition.AppendEntry('C', None)
    definition.AppendEntry('D', 'C')
    definition.Finalize()
    self.assertEqual(collections.OrderedDict([('A', 0),
                                              ('B', 0),
                                              ('C', 1),
                                              ('D', 1)]),
                     definition.entries)

  def testEnumValueAssignmentRaises(self):
    definition = EnumDefinition('c', 'p', [])
    definition.AppendEntry('A', None)
    definition.AppendEntry('B', '1')
    definition.AppendEntry('C', None)
    with self.assertRaises(Exception):
      definition.Finalize()

  def testExplicitPrefixStripping(self):
    definition = EnumDefinition('c', 'p', [])
    definition.AppendEntry('P_A', None)
    definition.AppendEntry('B', None)
    definition.AppendEntry('P_C', None)
    definition.prefix_to_strip = 'P_'
    definition.Finalize()
    self.assertEqual(['A', 'B', 'C'], definition.entries.keys())

  def testImplicitPrefixStripping(self):
    definition = EnumDefinition('ClassName', 'p', [])
    definition.AppendEntry('CLASS_NAME_A', None)
    definition.AppendEntry('CLASS_NAME_B', None)
    definition.AppendEntry('CLASS_NAME_C', None)
    definition.Finalize()
    self.assertEqual(['A', 'B', 'C'], definition.entries.keys())

  def testImplicitPrefixStrippingRequiresAllConstantsToBePrefixed(self):
    definition = EnumDefinition('Name', 'p', [])
    definition.AppendEntry('A', None)
    definition.AppendEntry('B', None)
    definition.AppendEntry('NAME_LAST', None)
    definition.Finalize()
    self.assertEqual(['A', 'B', 'NAME_LAST'], definition.entries.keys())


if __name__ == '__main__':
  unittest.main()
