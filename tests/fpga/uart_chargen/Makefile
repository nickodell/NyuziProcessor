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

TOPDIR=../../..

include $(TOPDIR)/build/target.mk

chargen.hex: chargen.c
	$(CC) $(CFLAGS) chargen.c -o chargen.elf ../../../software/libs/libc/crt0.o
	$(ELF2HEX) -o chargen.hex chargen.elf

fpgarun: chargen.hex
	$(SERIAL_BOOT) $(SERIAL_PORT) chargen.hex

run-verilator: chargen.hex
	../../../bin/verilator_model +bin=chargen.hex

clean: FORCE
	rm -f chargen.elf chargen.hex

FORCE:

