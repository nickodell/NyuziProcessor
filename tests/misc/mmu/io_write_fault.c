//
// Copyright 2015 Jeff Bush
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#include <stdio.h>
#include "mmu_test_common.h"

unsigned int globaltmp;

// Test that writing memory mapped I/O from a supervisor page from
// user mode faults.

int main(void)
{
    mapProgramAndStack();
    addDtlbMapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE
                   | TLB_PRESENT);

    // Alias mapping that we will use for test (the normal mapped region is used
    // to halt the test). This is supervisor and non-writab
    addDtlbMapping(0x100000, IO_REGION_BASE | TLB_PRESENT);

    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, (unsigned int) dumpFaultInfo);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);


    *((volatile unsigned int*) 0x100000) = 0x12;
    // CHECK: FAULT 7 00100000 current flags 06 prev flags 06

    // XXX no way to verify that the write wasn't sent to external bus

    printf("should_not_be_here\n"); // CHECKN: should_not_be_here
}

