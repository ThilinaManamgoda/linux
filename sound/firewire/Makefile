# SPDX-License-Identifier: GPL-2.0
# To find a header included by define_trace.h.
CFLAGS_amdtp-stream.o	:= -I$(src)

snd-firewire-lib-y := lib.o iso-resources.o packets-buffer.o \
			 fcp.o cmp.o amdtp-stream.o amdtp-am824.o
snd-isight-y := isight.o

obj-$(CONFIG_SND_FIREWIRE_LIB) += snd-firewire-lib.o
obj-$(CONFIG_SND_DICE) += dice/
obj-$(CONFIG_SND_OXFW) += oxfw/
obj-$(CONFIG_SND_ISIGHT) += snd-isight.o
obj-$(CONFIG_SND_FIREWORKS) += fireworks/
obj-$(CONFIG_SND_BEBOB) += bebob/
obj-$(CONFIG_SND_FIREWIRE_DIGI00X) += digi00x/
obj-$(CONFIG_SND_FIREWIRE_TASCAM) += tascam/
obj-$(CONFIG_SND_FIREWIRE_MOTU) += motu/
obj-$(CONFIG_SND_FIREFACE) += fireface/
