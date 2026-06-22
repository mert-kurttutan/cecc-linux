// SPDX-License-Identifier: GPL-2.0-or-later

#define CASPER_DISPLAY_MODE 0x0203

enum casper_gpu_mode {
	CASPER_GPU_MODE_HYBRID = 1,
	CASPER_GPU_MODE_DISCRETE = 2,
	CASPER_GPU_MODE_UMA = 3,
};

static struct casper_drv *casper_gpu_mode_drv;

static const char *casper_gpu_mode_name(enum casper_gpu_mode mode)
{
	switch (mode) {
	case CASPER_GPU_MODE_HYBRID:
		return "hybrid";
	case CASPER_GPU_MODE_DISCRETE:
		return "discrete";
	case CASPER_GPU_MODE_UMA:
		return "uma";
	default:
		return NULL;
	}
}

static int casper_gpu_mode_parse(const char *value, enum casper_gpu_mode *mode)
{
	if (sysfs_streq(value, "1") || sysfs_streq(value, "hybrid")) {
		*mode = CASPER_GPU_MODE_HYBRID;
		return 0;
	}
	if (sysfs_streq(value, "2") || sysfs_streq(value, "discrete")) {
		*mode = CASPER_GPU_MODE_DISCRETE;
		return 0;
	}
	if (sysfs_streq(value, "3") || sysfs_streq(value, "uma")) {
		*mode = CASPER_GPU_MODE_UMA;
		return 0;
	}

	return -EINVAL;
}

static int casper_gpu_mode_get(enum casper_gpu_mode *mode)
{
	struct casper_wmi_args out = { 0 };
	int ret;

	if (!casper_gpu_mode_drv)
		return -ENODEV;

	ret = casper_query(casper_gpu_mode_drv, CASPER_DISPLAY_MODE, &out);
	if (ret)
		return ret;

	switch (out.a2) {
	case CASPER_GPU_MODE_HYBRID:
	case CASPER_GPU_MODE_DISCRETE:
	case CASPER_GPU_MODE_UMA:
		*mode = out.a2;
		return 0;
	default:
		return -EINVAL;
	}
}

static int casper_gpu_mode_set(enum casper_gpu_mode mode)
{
	if (!casper_gpu_mode_drv)
		return -ENODEV;

	return casper_set(casper_gpu_mode_drv, CASPER_DISPLAY_MODE, mode, 0);
}

static int casper_gpu_mode_param_get(char *buffer, const struct kernel_param *kp)
{
	enum casper_gpu_mode mode;
	const char *name;
	int ret;

	ret = casper_gpu_mode_get(&mode);
	if (ret)
		return ret;

	name = casper_gpu_mode_name(mode);
	if (!name)
		return -EINVAL;

	return sysfs_emit(buffer, "%s\n", name);
}

static int casper_gpu_mode_param_set(const char *value, const struct kernel_param *kp)
{
	enum casper_gpu_mode mode;
	int ret;

	ret = casper_gpu_mode_parse(value, &mode);
	if (ret)
		return ret;

	return casper_gpu_mode_set(mode);
}

static const struct kernel_param_ops casper_gpu_mode_param_ops = {
	.get = casper_gpu_mode_param_get,
	.set = casper_gpu_mode_param_set,
};

module_param_cb(gpu_mode, &casper_gpu_mode_param_ops, NULL, 0644);
MODULE_PARM_DESC(gpu_mode, "Casper GPU mode control: hybrid, discrete, uma");

static int casper_gpu_mode_backend_register(struct casper_drv *drv)
{
	if (casper_gpu_mode_drv && casper_gpu_mode_drv != drv)
		return -EBUSY;

	casper_gpu_mode_drv = drv;
	return 0;
}

static void casper_gpu_mode_backend_unregister(struct casper_drv *drv)
{
	if (casper_gpu_mode_drv == drv)
		casper_gpu_mode_drv = NULL;
}
