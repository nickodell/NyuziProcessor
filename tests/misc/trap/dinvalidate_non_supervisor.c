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

//
// Ensure that attempting to execute the 'dinvalidate' instruction faults if the
// thread is in user mode.
// XXX there isn't an easy way to ensure the side effect of the instruction didn't
// occur.
//

void faultHandler(void)
{
    printf("FAULT %d current flags %02x prev flags %02x\n",
           __builtin_nyuzi_read_control_reg(3),
           __builtin_nyuzi_read_control_reg(4),
           __builtin_nyuzi_read_control_reg(8));

    exit(0);
}

// Make this a call to flush the pipeline
void __attribute__((noinline)) switchToUserMode(void)
{
    __builtin_nyuzi_write_control_reg(4, 0);
}

int main(void)
{
    volatile unsigned int * const test_loc = (volatile unsigned int*) 0x100000;

    __builtin_nyuzi_write_control_reg(1, faultHandler);

    switchToUserMode();

    // This will fault
    *test_loc = 0x12345678;

    asm("dinvalidate %0" : : "r" (test_loc)); // CHECK: FAULT 10 current flags 04 prev flags 00

    printf("should_not_be_here\n"); // CHECKN: should_not_be_here
}

