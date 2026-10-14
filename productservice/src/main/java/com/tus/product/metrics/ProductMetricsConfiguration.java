package com.tus.product.metrics;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.micrometer.core.instrument.MeterRegistry;

@Configuration
public class ProductMetricsConfiguration {

	@Bean
	public ProductMetrics productMetrics(MeterRegistry registry) {
		return new ProductMetrics(registry);
	}
}
