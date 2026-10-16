// SPDX-License-Identifier: GPL-2.0
/*
 * Mainline devfreq glue for the Rockchip RKNPU driver.
 *
 * The vendor driver depends on Rockchip-only OPP/system-monitor helpers. This
 * port uses the generic OPP helpers with the board's rknpu-supply regulator and
 * feeds simple_ondemand from the driver's per-core hardware busy-time counters.
 */

#include <linux/clk.h>
#include <linux/devfreq.h>
#include <linux/device.h>
#include <linux/pm_opp.h>
#include <linux/pm_runtime.h>

#include "rknpu_drv.h"
#include "rknpu_devfreq.h"

static int rknpu_devfreq_target(struct device *dev, unsigned long *freq,
				u32 flags)
{
	struct rknpu_device *rknpu_dev = dev_get_drvdata(dev);
	struct dev_pm_opp *opp;
	unsigned long target = *freq;
	unsigned long voltage;
	int ret;

	opp = devfreq_recommended_opp(dev, &target, flags);
	if (IS_ERR(opp))
		return PTR_ERR(opp);

	voltage = dev_pm_opp_get_voltage(opp);
	dev_pm_opp_put(opp);

	if (target == rknpu_dev->current_freq)
		return 0;

	ret = dev_pm_opp_set_rate(dev, target);
	if (ret)
		return ret;

	rknpu_dev->current_freq = target;
	rknpu_dev->current_volt = voltage;
	if (rknpu_dev->devfreq)
		rknpu_dev->devfreq->last_status.current_frequency = target;

	dev_dbg(dev, "set rknpu freq: %lu Hz, volt: %lu uV\n", target, voltage);
	return 0;
}

static int rknpu_devfreq_get_dev_status(struct device *dev,
					struct devfreq_dev_status *stat)
{
	struct rknpu_device *rknpu_dev = dev_get_drvdata(dev);
	u64 busy_time = 0;
	unsigned long flags;
	int i;

	spin_lock_irqsave(&rknpu_dev->irq_lock, flags);
	for (i = 0; i < rknpu_dev->config->num_irqs; i++)
		busy_time += ktime_to_ns(
			rknpu_dev->subcore_datas[i].timer.total_busy_time);
	spin_unlock_irqrestore(&rknpu_dev->irq_lock, flags);

	/* Each core reports busy time in a shared one-second sampling window. */
	stat->total_time = RKNPU_LOAD_INTERVAL;
	stat->busy_time = min_t(u64, busy_time, stat->total_time);
	stat->current_frequency = rknpu_dev->current_freq;

	return 0;
}

static int rknpu_devfreq_get_cur_freq(struct device *dev, unsigned long *freq)
{
	struct rknpu_device *rknpu_dev = dev_get_drvdata(dev);

	*freq = rknpu_dev->current_freq;
	return 0;
}

static struct devfreq_dev_profile rknpu_devfreq_profile = {
	.polling_ms = 1000,
	.target = rknpu_devfreq_target,
	.get_dev_status = rknpu_devfreq_get_dev_status,
	.get_cur_freq = rknpu_devfreq_get_cur_freq,
};

void rknpu_devfreq_lock(struct rknpu_device *rknpu_dev)
{
}
EXPORT_SYMBOL(rknpu_devfreq_lock);

void rknpu_devfreq_unlock(struct rknpu_device *rknpu_dev)
{
}
EXPORT_SYMBOL(rknpu_devfreq_unlock);

int rknpu_devfreq_init(struct rknpu_device *rknpu_dev)
{
	struct device *dev = rknpu_dev->dev;
	static const char * const clk_names[] = { "clk_npu", NULL };
	static const char * const regulator_names[] = { "rknpu", NULL };
	struct dev_pm_opp_config opp_config = {
		.clk_names = clk_names,
		.regulator_names = regulator_names,
	};
	struct dev_pm_opp *opp;
	int ret;

	/* Generic OPP needs both associations before parsing the DT table;
	 * otherwise dev_pm_opp_set_rate() changes only the clock and silently
	 * leaves vdd_npu_s0 at its boot voltage.
	 */
	ret = devm_pm_opp_set_config(dev, &opp_config);
	if (ret < 0)
		return ret;

	ret = devm_pm_opp_of_add_table(dev);
	if (ret) {
		dev_err(dev, "failed to add NPU OPP table: %d\n", ret);
		return ret;
	}

	rknpu_dev->current_freq = clk_get_rate(rknpu_dev->clks[0].clk);
	opp = devfreq_recommended_opp(dev, &rknpu_dev->current_freq, 0);
	if (IS_ERR(opp)) {
		dev_err(dev, "failed to find current NPU OPP\n");
		return PTR_ERR(opp);
	}
	dev_pm_opp_put(opp);

	rknpu_dev->current_volt = regulator_get_voltage(rknpu_dev->vdd);
	rknpu_devfreq_profile.initial_freq = rknpu_dev->current_freq;

	rknpu_dev->devfreq = devm_devfreq_add_device(
		dev, &rknpu_devfreq_profile, "simple_ondemand", NULL);
	if (IS_ERR(rknpu_dev->devfreq)) {
		dev_err(dev, "failed to register NPU devfreq: %ld\n",
			PTR_ERR(rknpu_dev->devfreq));
		rknpu_dev->devfreq = NULL;
		return PTR_ERR(rknpu_dev->devfreq);
	}

	return 0;
}
EXPORT_SYMBOL(rknpu_devfreq_init);

void rknpu_devfreq_remove(struct rknpu_device *rknpu_dev)
{
	rknpu_dev->devfreq = NULL;
}
EXPORT_SYMBOL(rknpu_devfreq_remove);

int rknpu_devfreq_runtime_suspend(struct device *dev)
{
	return 0;
}
EXPORT_SYMBOL(rknpu_devfreq_runtime_suspend);

int rknpu_devfreq_runtime_resume(struct device *dev)
{
	return 0;
}
EXPORT_SYMBOL(rknpu_devfreq_runtime_resume);
