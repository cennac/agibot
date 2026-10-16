// SPDX-License-Identifier: GPL-2.0-only
/*
 * Explicit reset pulse sequencing for the two onboard USB hubs on AGIBOT
 * MB0002 V2.  The legacy vendor tree used a private usbhub_rst node; this
 * driver implements the same low pulse/release/wait behavior with a standard
 * reset-gpios binding.
 */

#include <linux/delay.h>
#include <linux/device.h>
#include <linux/gpio/consumer.h>
#include <linux/module.h>
#include <linux/mod_devicetable.h>
#include <linux/platform_device.h>
#include <linux/property.h>

struct agibot_hub_reset {
	struct gpio_descs *reset_gpios;
	struct gpio_descs *enable_gpios;
	u32 assert_us;
	u32 power_on_delay_us;
	u32 post_delay_us;
};

static int agibot_hub_reset_probe(struct platform_device *pdev)
{
	struct agibot_hub_reset *hub;
	struct device *dev = &pdev->dev;
	int i;

	hub = devm_kzalloc(dev, sizeof(*hub), GFP_KERNEL);
	if (!hub)
		return -ENOMEM;

	device_property_read_u32(dev, "reset-assert-us", &hub->assert_us);
	device_property_read_u32(dev, "power-on-delay-us",
				 &hub->power_on_delay_us);
	device_property_read_u32(dev, "reset-post-delay-us", &hub->post_delay_us);

	/* ACTIVE_LOW reset lines: logical high asserts, logical low releases. */
	hub->reset_gpios = devm_gpiod_get_array(dev, "reset", GPIOD_OUT_HIGH);
	if (IS_ERR(hub->reset_gpios))
		return dev_err_probe(dev, PTR_ERR(hub->reset_gpios),
				     "failed to acquire hub reset GPIOs\n");

	hub->enable_gpios = devm_gpiod_get_array(dev, "enable", GPIOD_OUT_LOW);
	if (IS_ERR(hub->enable_gpios))
		return dev_err_probe(dev, PTR_ERR(hub->enable_gpios),
				     "failed to acquire hub power GPIOs\n");

	for (i = 0; i < hub->enable_gpios->ndescs; ++i)
		gpiod_set_value_cansleep(hub->enable_gpios->desc[i], 1);

	fsleep(hub->power_on_delay_us);
	fsleep(hub->assert_us);

	for (i = 0; i < hub->reset_gpios->ndescs; ++i)
		gpiod_set_value_cansleep(hub->reset_gpios->desc[i], 0);

	fsleep(hub->post_delay_us);
	platform_set_drvdata(pdev, hub);

	dev_info(dev, "enabled %d USB power rails and released %d hub resets\n",
		 hub->enable_gpios->ndescs, hub->reset_gpios->ndescs);

	return 0;
}

static const struct of_device_id agibot_hub_reset_of_match[] = {
	{ .compatible = "agibot,mb0002-usb-hub-reset" },
	{ }
};
MODULE_DEVICE_TABLE(of, agibot_hub_reset_of_match);

static struct platform_driver agibot_hub_reset_driver = {
	.probe = agibot_hub_reset_probe,
	.driver = {
		.name = "agibot-hub-reset",
		.of_match_table = agibot_hub_reset_of_match,
	},
};
module_platform_driver(agibot_hub_reset_driver);

MODULE_AUTHOR("AGIBOT Android port");
MODULE_DESCRIPTION("AGIBOT MB0002 V2 USB hub reset driver");
MODULE_LICENSE("GPL");
