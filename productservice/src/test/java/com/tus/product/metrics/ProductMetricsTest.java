package com.tus.product.metrics;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.Set;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import io.micrometer.core.instrument.Meter;
import io.micrometer.core.instrument.Tag;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import io.micrometer.prometheus.PrometheusConfig;
import io.micrometer.prometheus.PrometheusMeterRegistry;
import org.springframework.web.client.RestClientException;

class ProductMetricsTest {

	private static final Set<String> ALLOWED_TAGS = Set.of("application", "operation", "status", "exception");

	private SimpleMeterRegistry registry;
	private ProductMetrics metrics;

	@BeforeEach
	void setUp() {
		registry = new SimpleMeterRegistry();
		metrics = new ProductMetrics(registry);
	}

	@Test
	void couponClientRecordsDurationOnSuccessWithoutAnError() {
		String result = metrics.recordCouponClient(() -> "coupon");

		assertThat(result).isEqualTo("coupon");
		assertThat(registry.get(ProductMetrics.COUPON_CLIENT_DURATION).tag("status", "success").timer().count())
				.isEqualTo(1);
		assertThat(registry.find(ProductMetrics.COUPON_CLIENT_ERRORS).counters()).isEmpty();
	}

	@Test
	void couponClientRecordsDurationAndErrorWhenTheCallFails() {
		assertThatThrownBy(() -> metrics.recordCouponClient(() -> {
			throw new RestClientException("down");
		})).isInstanceOf(RestClientException.class);

		assertThat(registry.get(ProductMetrics.COUPON_CLIENT_DURATION)
				.tag("status", "error")
				.tag("exception", "RestClientException")
				.timer().count()).isEqualTo(1);
		assertThat(registry.get(ProductMetrics.COUPON_CLIENT_ERRORS)
				.tag("exception", "RestClientException")
				.counter().count()).isEqualTo(1);
	}

	@Test
	void couponClientTreatsAMissingCouponAsAnError() {
		assertThatThrownBy(() -> metrics.recordCouponClient(() -> null))
				.isInstanceOf(CouponClientException.class);

		assertThat(registry.get(ProductMetrics.COUPON_CLIENT_ERRORS)
				.tag("exception", "CouponClientException")
				.counter().count()).isEqualTo(1);
		assertThat(registry.get(ProductMetrics.COUPON_CLIENT_DURATION).tag("status", "error").timer().count())
				.isEqualTo(1);
	}

	@Test
	void databaseTimerRecordsFailedCalls() {
		assertThatThrownBy(() -> metrics.recordDatabase("save", () -> {
			throw new IllegalStateException("db");
		})).isInstanceOf(IllegalStateException.class);

		assertThat(registry.get(ProductMetrics.DB_OPERATION_DURATION)
				.tag("operation", "save")
				.tag("status", "error")
				.tag("exception", "IllegalStateException")
				.timer().count()).isEqualTo(1);
	}

	@Test
	void labelsStayWithinTheFixedSet() {
		metrics.recordCouponClient(() -> "coupon");
		metrics.recordDatabase("save", () -> "row");
		metrics.recordOperation("create", true, null);

		for (Meter meter : registry.getMeters()) {
			for (Tag tag : meter.getId().getTags()) {
				if ("le".equals(tag.getKey())) {
					continue;
				}
				assertThat(ALLOWED_TAGS).contains(tag.getKey());
				assertThat(tag.getValue()).doesNotContain("SAVE10");
			}
		}
	}

	@Test
	void prometheusNamesMatchMicrometerSuffixes() {
		PrometheusMeterRegistry prometheus = new PrometheusMeterRegistry(PrometheusConfig.DEFAULT);
		prometheus.config().commonTags("application", "productservice");
		ProductMetrics exported = new ProductMetrics(prometheus);

		exported.recordCouponClient(() -> "coupon");
		assertThatThrownBy(() -> exported.recordCouponClient(() -> {
			throw new RestClientException("down");
		})).isInstanceOf(RestClientException.class);
		exported.recordDatabase("save", () -> "row");
		exported.recordOperation("create", false, new RestClientException("down"));

		String scrape = prometheus.scrape();
		assertThat(scrape).contains("coupon_client_request_duration_seconds_bucket");
		assertThat(scrape).contains("coupon_client_request_duration_seconds_count");
		assertThat(scrape).contains("coupon_client_request_duration_seconds_sum");
		assertThat(scrape).contains("coupon_client_errors_total");
		assertThat(scrape).contains("product_db_operation_duration_seconds_bucket");
		assertThat(scrape).contains("product_db_operation_duration_seconds_count");
		assertThat(scrape).contains("product_operation_total");
		assertThat(scrape).contains("le=\"0.05\"");
		assertThat(scrape).contains("le=\"0.01\"");
		assertThat(scrape).doesNotContain("product_api_requests_total");
	}
}
