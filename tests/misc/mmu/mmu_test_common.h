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

#pragma once

#include <stdlib.h>

#define PAGE_SIZE 0x1000
#define IO_REGION_BASE 0xffff0000

#define TLB_PRESENT 1
#define TLB_WRITABLE (1 << 1)
#define TLB_EXECUTABLE (1 << 2)
#define TLB_SUPERVISOR (1 << 3)
#define TLB_GLOBAL (1 << 4)

#define CR_FAULT_HANDLER 1
#define CR_FAULT_PC 2
#define CR_FAULT_REASON 3
#define CR_FLAGS 4
#define CR_FAULT_ADDRESS 5
#define CR_TLB_MISS_HANDLER 7
#define CR_SAVED_FLAGS 8
#define CR_CURRENT_ASID 9
#define CR_SCRATCHPAD0 11
#define CR_SCRATCHPAD1 12
#define CR_SUBCYCLE 13

#define FLAG_MMU_EN (1 << 1)
#define FLAG_SUPERVISOR_EN (1 << 2)

#define INSTRUCTION_RET 0xc0ff03e0

// in identity_tlb_miss_handler.s
extern void tlb_miss_handler();

void addItlbMapping(unsigned int va, unsigned int pa)
{
    asm volatile("itlbinsert %0, %1" : : "r" (va), "r" (pa));
}

void addDtlbMapping(unsigned int va, unsigned int pa)
{
    asm volatile("dtlbinsert %0, %1" : : "r" (va), "r" (pa));
}

// Make this a call to flush the pipeline
void __attribute__((noinline)) switchToUserMode(void)
{
    __builtin_nyuzi_write_control_reg(CR_FLAGS, __builtin_nyuzi_read_control_reg(CR_FLAGS)
                                      & ~FLAG_SUPERVISOR_EN);
}

// Make this an explicit call to flush the pipeline
static void __attribute__((noinline)) setAsid(int asid)
{
    __builtin_nyuzi_write_control_reg(CR_CURRENT_ASID, asid);
}

static void mapProgramAndStack(void)
{
    unsigned int va;

    // Take the address of a local variable to find stack pointer
    unsigned int stack_addr = ((unsigned int) &va) & ~(PAGE_SIZE - 1);

    // Map code & data
    for (va = 0; va < 0x10000; va += PAGE_SIZE)
    {
        addItlbMapping(va, va | TLB_EXECUTABLE | TLB_GLOBAL | TLB_PRESENT);
        addDtlbMapping(va, va | TLB_WRITABLE | TLB_GLOBAL | TLB_PRESENT);
    }

    addDtlbMapping(stack_addr, stack_addr | TLB_GLOBAL | TLB_WRITABLE | TLB_PRESENT);
}

static void dumpFaultInfo(void)
{
    printf("FAULT %d %08x current flags %02x prev flags %02x\n",
           __builtin_nyuzi_read_control_reg(CR_FAULT_REASON),
           __builtin_nyuzi_read_control_reg(CR_FAULT_ADDRESS),
           __builtin_nyuzi_read_control_reg(CR_FLAGS),
           __builtin_nyuzi_read_control_reg(CR_SAVED_FLAGS));
    exit(0);
}
