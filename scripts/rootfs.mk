DEFAULT_OF=rootfs.img
DEFAULT_COUNT=128K
LINUX_KERNEL_VERSION=3.14.5
BUSYBOX_VERSION=1.22.1
CT_NG_VERSION=1.19.0

help:
	@echo "\n\tdownload target"
	@echo "\n\tdescription : download a specific version of the linux kernel and busybox\n"
	@echo "\n\textract_resources target"
	@echo "\n\tdescription : extract the previous linux kernel and busybox downloaded\n"
	@echo "\n\traw_rootfs target"
	@echo "\n\tdescription : create a raw zeroed file"
	@echo "\n\targument :"
	@echo "\t\t- OF : output file name"
	@echo "\t\t- COUNT : number of blocs to write (see man dd)\n"
	@echo
	@echo "\n\tformat_file target\n"
	@echo "\tdescription : format a raw file with an ext4 filesystem"
	@echo "\n\targument :"
	@echo "\t\t- no argument whether called after raw_rootfs target"
	@echo "\t\t- if call independently, see argument of raw_rootfs target\n"
	@echo "\n\tlauch target\n"
	@echo "\tdescription : Launch rootfs and kernel inside qemu, make the entire creation process if rootfs and kernel don't exist"
	@echo "\n\targument : it takes no arguments"

download : resources/linux-$(LINUX_KERNEL_VERSION).tar.xz resources/busybox-$(BUSYBOX_VERSION).tar.bz2 resources/crosstool-ng-$(CT_NG_VERSION).tar.bz2
resources/linux-$(LINUX_KERNEL_VERSION).tar.xz :
	wget -P resources ftp://ftp.kernel.org/pub/linux/kernel/v3.x/linux-$(LINUX_KERNEL_VERSION).tar.xz
resources/busybox-$(BUSYBOX_VERSION).tar.bz2 :
	wget -P resources http://www.busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2
resources/crosstool-ng-$(CT_NG_VERSION).tar.bz2 :
	wget -P resources http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-$(CT_NG_VERSION).tar.bz2


resources/linux-$(LINUX_KERNEL_VERSION) :
	tar --directory=resources -xJf resources/linux-$(LINUX_KERNEL_VERSION).tar.xz
resources/busybox-$(BUSYBOX_VERSION) :
	tar --directory=resources -xjf resources/busybox-$(BUSYBOX_VERSION).tar.bz2
resources/crosstool-ng-$(CT_NG_VERSION) :
	tar --directory=resources -xjf resources/crosstool-ng-$(CT_NG_VERSION).tar.bz2


make_kernel : resources/linux-$(LINUX_KERNEL_VERSION) resources/linux-$(LINUX_KERNEL_VERSION)/arch/x86_64/boot/bzImage
	make -C resources/linux-$(LINUX_KERNEL_VERSION) x86_64_defconfig
	make -C resources/linux-$(LINUX_KERNEL_VERSION)

build_compilation_env :
	@echo "don't forget to build manually your compilation env to have a proper libc (compiled against the proper kernel header) to build a proper busybox"

resources/busybox-$(BUSYBOX_VERSION)/_install/bin/busybox : resources/busybox-$(BUSYBOX_VERSION)
	cp resources/busybox-$(BUSYBOX_VERSION)_config resources/busybox-$(BUSYBOX_VERSION)/.config
	make -C resources/busybox-$(BUSYBOX_VERSION)
	make -C resources/busybox-$(BUSYBOX_VERSION) install

# Doesn't work for the moment
#ifdef OF
#	DEFAULT_OF=$(OF)
#endif

#ifdef COUNT
#	DEFAULT_COUNT=$(COUNT)
#endif

$(DEFAULT_OF) :
	dd if=/dev/zero of=$(DEFAULT_OF) count=$(DEFAULT_COUNT)
	sudo mkfs -t ext4 -i 1024 -F $(DEFAULT_OF)


populate_rootfs : .stamp_populate_rootfs
.stamp_populate_rootfs : resources/busybox-$(BUSYBOX_VERSION)/_install/bin/busybox $(DEFAULT_OF)
	sudo mount -o loop $(DEFAULT_OF) /mnt
	sudo rsync -a resources/busybox-$(BUSYBOX_VERSION)/_install/ /mnt
	sudo chown -R root:root /mnt
	sudo cp -rf overlay_fs/* /mnt
	sudo chmod -R 777 /mnt/*
	sync
	sudo umount /mnt
	touch $@

launch : populate_rootfs make_kernel
	qemu-system-x86_64 -hda rootfs.img -kernel resources/linux-$(LINUX_KERNEL_VERSION)/arch/x86/boot/bzImage -append "root=/dev/sda rw console=ttyS0" -nographic

V=something
ifdef V1
	V=$(V1)
endif
test:
	@echo $(V)
