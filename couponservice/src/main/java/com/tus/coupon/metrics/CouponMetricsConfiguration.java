package com.tus.coupon.metrics;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.micrometer.core.instrument.MeterRegistry;

@Configuration
public class CouponMetricsConfiguration {

	@Bean
	public CouponMetrics couponMetrics(MeterRegistry registry) {
		return new CouponMetrics(registry);
	}
}
