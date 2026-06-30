obj-m += casper-wmi.o

KDIR ?= /lib/modules/$(shell uname -r)/build
OUT_DIR ?= $(PWD)/out

all:
	mkdir -p $(OUT_DIR)
	make -C $(KDIR) M=$(PWD) MO=$(OUT_DIR) modules

clean:
	make -C $(KDIR) M=$(PWD) MO=$(OUT_DIR) clean
	rm -rf $(OUT_DIR)

install:
	mkdir -p $(OUT_DIR)
	make -C $(KDIR) M=$(PWD) MO=$(OUT_DIR) modules_install
