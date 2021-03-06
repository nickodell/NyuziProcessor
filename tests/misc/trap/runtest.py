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

import stat
import subprocess
import sys
import time

sys.path.insert(0, '../..')
from test_harness import *


def run_io_interrupt(name):
    compile_test(['io_interrupt.c', 'trap_handler.s'])
    result = run_verilator()
    lines = result.split('\n')
    output = None
    for x in lines:
        if x.startswith('>>'):
            output = x[2:]

    if output is None:
        raise TestException(
            'Could not find output string:\n' + result)

    # Make sure enough interrupts were triggered
    if output.count('*') < 2:
        raise TestException(
            'Not enough interrupts triggered:\n' + result)

    # Make sure we see at least some of the base string printed after an
    # interrupt
    if output.find('*') >= len(output) - 1:
        raise TestException(
            'No instances of interrupt return:\n' + result)

    # Remove all asterisks (interrupts) and make sure string is intact
    if output.replace(
            '*',
            '') != 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789':
        raise TestException(
            'Base string does not match:\n' + result)


def run_multicycle(name):
    assemble_test('multicycle.s')
    result = run_verilator()
    if result.find('PASS') == -1 or result.find('FAIL') != -1:
        raise TestException('Test failed:\n' + result)


def run_unaligned_data_fault(name):
    compile_test(['unaligned_data_fault.c', 'trap_handler.s'])
    if name.endswith('_emulator'):
        result = run_emulator()
    else:
        result = run_verilator()

    check_result('unaligned_data_fault.c', result)


def run_illegal_instruction(name):
    compile_test(
        ['illegal_instruction.c', 'trap_handler.s', 'gen_illegal_inst_trap.S'])
    if name.endswith('_emulator'):
        result = run_emulator()
    else:
        result = run_verilator()

    check_result('gen_illegal_inst_trap.S', result)


# Test the mechanism for delivering interrupts to the emulator from a
# separate host process (useful for co-emulation)
# XXX A number of error cases do not clean up resources
def run_recv_host_interrupt(name):
    PIPE_NAME = '/tmp/nyuzi_emulator_recvint'
    try:
        os.remove(PIPE_NAME)
    except:
        pass

    compile_test(['recv_host_interrupt.c', 'trap_handler.s'])

    os.mknod(PIPE_NAME, stat.S_IFIFO | 0666)


    args = [BIN_DIR + 'emulator', '-i', PIPE_NAME, HEX_FILE]
    process = subprocess.Popen(args, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)

    try:
        interruptPipe = os.open(PIPE_NAME, os.O_WRONLY)

        # Send periodic interrupts to process
        for x in range(5):
            os.write(interruptPipe, chr(x))
            time.sleep(0.2)

        # Wait for completion
        result, unused_err = TimedProcessRunner().communicate(process, 60)
        check_result('recv_host_interrupt.c', result)
    finally:
        os.close(interruptPipe)
        os.unlink(PIPE_NAME)

# XXX A number of error cases do not clean up resources
def run_send_host_interrupt(name):
    PIPE_NAME = '/tmp/nyuzi_emulator_sendint'
    try:
        os.remove(PIPE_NAME)
    except:
        pass

    compile_test(['send_host_interrupt.c'])

    os.mknod(PIPE_NAME, stat.S_IFIFO | 0666)

    args = [BIN_DIR + 'emulator', '-o', PIPE_NAME, HEX_FILE]
    process = subprocess.Popen(args, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)

    try:
        interruptPipe = os.open(PIPE_NAME, os.O_RDONLY | os.O_NONBLOCK)
        result, unused_err = TimedProcessRunner().communicate(process, 60)

        # Interrupts should be in pipe now
        interrupts = os.read(interruptPipe, 5)
        if interrupts != '\x05\x06\x07\x08\x09':
            raise TestException('Did not receive proper host interrupts')
    finally:
        os.close(interruptPipe)
        os.unlink(PIPE_NAME)

register_tests(run_io_interrupt, ['io_interrupt'])
register_tests(run_multicycle, ['multicycle'])
register_tests(run_recv_host_interrupt, ['recv_host_interrupt'])
register_tests(run_send_host_interrupt, ['send_host_interrupt'])
register_generic_test('creg_non_supervisor')
register_generic_test('eret_non_supervisor')
register_generic_test('dinvalidate_non_supervisor')
register_generic_test('inst_align_fault')
register_tests(
    run_unaligned_data_fault, [
        'unaligned_data_fault_emulator', 'unaligned_data_fault_verilator'])
register_tests(
    run_illegal_instruction, [
        'illegal_instruction_emulator', 'illegal_instruction_verilator'])
register_generic_test('syscall')

execute_tests()
