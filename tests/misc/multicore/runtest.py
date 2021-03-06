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

import sys
import struct

# Test load_sync/store_sync instructions by having four threads update
# variables round-robin.

sys.path.insert(0, '../..')
from test_harness import *


def multicore_test(name):
    compile_test('multicore.c')
    result = run_verilator()
    if result.replace('\n', '').find(
            '012345678910111213141516171819202122232425262728293031') == -1:
        raise TestException('Output mismatch:\n' + result)

register_tests(multicore_test, ['multicore'])
execute_tests()
