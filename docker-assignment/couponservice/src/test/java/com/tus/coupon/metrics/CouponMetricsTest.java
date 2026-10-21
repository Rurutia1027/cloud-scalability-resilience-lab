package com.tus.coupon.metrics;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.util.Set;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;

import com.tus.coupon.model.Coupon;

import io.micrometer.core.instrument.Meter;
import io.micrometer.core.instrument.Tag;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import io.micrometer.prometheus.PrometheusConfig;
import io.micrometer.prometheus.PrometheusMeterRegistry;

class CouponMetricsTest {

	private static final Set<String> ALLOWED_TAGS = Set.of("application", "operation", "status", "exception");

	private SimpleMeterRegistry registry;
	private CouponMetrics metrics;

	@BeforeEach
	void setUp() {
		registry = new SimpleMeterRegistry();
		metrics = new CouponMetrics(registry);
	}

	@Test
	void lookupRecordsSuccessWithoutAnError() {
		Coupon coupon = coupon("SAVE10");

		Coupon found = metrics.recordLookup(() -> coupon);

		assertThat(found).isSameAs(coupon);
		assertThat(registry.get(CouponMetrics.LOOKUP).tag("status", "success").tag("exception", "none").counter()
				.count()).isEqualTo(1);
		assertThat(registry.get(CouponMetrics.LOOKUP_DURATION).tag("status", "success").timer().count()).isEqualTo(1);
		assertThat(registry.find(CouponMetrics.LOOKUP_ERRORS).counters()).isEmpty();
	}

	@Test
	void lookupRecordsNotFoundAsAFailureAndStillTimesTheCall() {
		Coupon found = metrics.recordLookup(() -> null);

		assertThat(found).isNull();
		assertThat(registry.get(CouponMetrics.LOOKUP).tag("status", "not_found").tag("exception", "NotFound").counter()
				.count()).isEqualTo(1);
		assertThat(registry.get(CouponMetrics.LOOKUP_ERRORS).tag("exception", "NotFound").counter().count())
				.isEqualTo(1);
		assertThat(registry.get(CouponMetrics.LOOKUP_DURATION).tag("status", "not_found").timer().count()).isEqualTo(1);
	}

	@Test
	void lookupRecordsDurationWhenTheRepositoryThrows() {
		assertThatThrownBy(() -> metrics.recordLookup(() -> {
			throw new DataAccessResourceFailureException("db");
		})).isInstanceOf(DataAccessResourceFailureException.class);

		assertThat(registry.get(CouponMetrics.LOOKUP).tag("status", "error")
				.tag("exception", "DataAccessResourceFailureException").counter().count()).isEqualTo(1);
		assertThat(registry.get(CouponMetrics.LOOKUP_ERRORS).tag("exception", "DataAccessResourceFailureException")
				.counter().count()).isEqualTo(1);
		assertThat(registry.get(CouponMetrics.LOOKUP_DURATION).tag("status", "error").timer().count()).isEqualTo(1);
	}

	@Test
	void labelsDoNotCarryTheCouponCode() {
		metrics.recordLookup(() -> coupon("SAVE10"));

		for (Meter meter : registry.getMeters()) {
			for (Tag tag : meter.getId().getTags()) {
				if ("le".equals(tag.getKey())) {
					continue;
				}
				assertThat(ALLOWED_TAGS).contains(tag.getKey());
				assertThat(tag.getValue()).isNotEqualTo("SAVE10");
			}
		}
	}

	@Test
	void prometheusNamesMatchMicrometerSuffixes() {
		PrometheusMeterRegistry prometheus = new PrometheusMeterRegistry(PrometheusConfig.DEFAULT);
		prometheus.config().commonTags("application", "couponservice");
		CouponMetrics exported = new CouponMetrics(prometheus);

		exported.recordLookup(() -> coupon("SAVE10"));
		exported.recordLookup(() -> null);

		String scrape = prometheus.scrape();
		assertThat(scrape).contains("coupon_lookup_total");
		assertThat(scrape).contains("coupon_lookup_errors_total");
		assertThat(scrape).contains("coupon_lookup_duration_seconds_bucket");
		assertThat(scrape).contains("coupon_lookup_duration_seconds_count");
		assertThat(scrape).contains("coupon_lookup_duration_seconds_sum");
		assertThat(scrape).contains("le=\"0.01\"");
		assertThat(scrape).doesNotContain("SAVE10");
		assertThat(scrape).doesNotContain("coupon_api_requests_total");
	}

	private static Coupon coupon(String code) {
		Coupon coupon = new Coupon();
		coupon.setCode(code);
		coupon.setDiscount(new BigDecimal("10"));
		return coupon;
	}
}
