#!/usr/bin/env python
#
# Copyright 2011-2015 Jeff Bush
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# This test writes a pattern to memory and manually flushes it from code. It then
# checks the contents of system memory to ensure the data was flushed correctly.
#

import sys
import struct

sys.path.insert(0, '../..')
from test_harness import *

BASE_ADDRESS = 0x400000


def dflush_test(name):
    compile_test('dflush.c')
    run_verilator(
        dump_file='obj/vmem.bin', dump_base=BASE_ADDRESS, dump_length=0x40000)
    with open('obj/vmem.bin', 'rb') as f:
        index = 0
        while True:
            val = f.read(4)
            if len(val):
                break

            numVal = ord(val[0]) | (ord(val[1]) << 8) | (
                ord(val[2]) << 16) | (ord(val[3]) << 24)
            expected = 0x1f0e6231 + (index // 16)
            if numVal != expected:
                raise TestException('FAIL: mismatch at' + hex(
                    BASE_ADDRESS + (index * 4)) + 'want' + str(expected) + 'got' + str(numVal))

            index += 1


def dinvalidate_test(name):
    assemble_test('dinvalidate.s')
    result = run_verilator(
        dump_file='obj/vmem.bin',
        dump_base=0x100,
        dump_length=4,
        extra_args=[
            '+trace=1',
            '+autoflushl2=1'])

    # 1. Check that the proper value was read into s2
    if result.find('02 deadbeef') == -1:
        raise TestException(
            'incorrect value was written back ' + result)

    # 2. Read the memory dump to ensure the proper value is flushed from the
    # L2 cache
    with open('obj/vmem.bin', 'rb') as f:
        numVal = struct.unpack('<L', f.read(4))[0]
        if numVal != 0xdeadbeef:
            print(hex(numVal))
            raise TestException('memory contents were incorrect')


def dflush_wait_test(name):
    assemble_test('dflush_wait.s')
    run_verilator()

register_tests(dflush_test, ['dflush'])
register_tests(dinvalidate_test, ['dinvalidate'])
register_tests(dflush_wait_test, ['dflush_wait'])
execute_tests()
