package com.tus.coupon.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataAccessResourceFailureException;

import com.tus.coupon.metrics.CouponMetrics;
import com.tus.coupon.model.Coupon;
import com.tus.coupon.repo.CouponRepo;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;

@ExtendWith(MockitoExtension.class)
class CouponRestControllerTest {

	@Mock
	private CouponRepo repo;

	private SimpleMeterRegistry registry;
	private CouponRestController controller;

	@BeforeEach
	void setUp() {
		registry = new SimpleMeterRegistry();
		controller = new CouponRestController(repo, new CouponMetrics(registry));
	}

	@Test
	void getByCodeRecordsASuccessfulLookup() {
		Coupon coupon = new Coupon();
		coupon.setCode("SAVE10");
		coupon.setDiscount(new BigDecimal("10"));
		when(repo.findByCode("SAVE10")).thenReturn(coupon);

		Coupon found = controller.getCouponByCouponCode("SAVE10");

		assertThat(found.getCode()).isEqualTo("SAVE10");
		assertThat(registry.get(CouponMetrics.LOOKUP).tag("status", "success").counter().count()).isEqualTo(1);
		assertThat(registry.find(CouponMetrics.LOOKUP_ERRORS).counters()).isEmpty();
	}

	@Test
	void getByCodeRecordsNotFoundWithoutUsingTheCodeAsALabel() {
		when(repo.findByCode("MISSING")).thenReturn(null);

		assertThat(controller.getCouponByCouponCode("MISSING")).isNull();

		assertThat(registry.get(CouponMetrics.LOOKUP_ERRORS).tag("exception", "NotFound").counter().count())
				.isEqualTo(1);
		assertThat(registry.get(CouponMetrics.LOOKUP).tag("status", "not_found").counter().count()).isEqualTo(1);
		registry.getMeters().forEach(meter -> meter.getId().getTags()
				.forEach(tag -> assertThat(tag.getValue()).isNotEqualTo("MISSING")));
	}

	@Test
	void getByCodeRecordsARepositoryFailure() {
		when(repo.findByCode("SAVE10")).thenThrow(new DataAccessResourceFailureException("db"));

		assertThatThrownBy(() -> controller.getCouponByCouponCode("SAVE10"))
				.isInstanceOf(DataAccessResourceFailureException.class);

		assertThat(registry.get(CouponMetrics.LOOKUP_DURATION).tag("status", "error").timer().count()).isEqualTo(1);
		assertThat(registry.get(CouponMetrics.LOOKUP_ERRORS).tag("exception", "DataAccessResourceFailureException")
				.counter().count()).isEqualTo(1);
	}
}
