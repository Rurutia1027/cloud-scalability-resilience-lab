package com.tus.product.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import java.math.BigDecimal;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import com.tus.product.metrics.CouponClientException;
import com.tus.product.metrics.ProductMetrics;
import com.tus.product.model.Product;
import com.tus.product.repos.ProductRepo;

import io.micrometer.core.instrument.Meter;
import io.micrometer.core.instrument.Tag;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;

@ExtendWith(MockitoExtension.class)
class ProductRestControllerTest {

	private static final String COUPON_URL = "http://localhost:9091/couponapi/coupons/";

	@Mock
	private ProductRepo repo;

	private SimpleMeterRegistry registry;
	private RestTemplate restTemplate;
	private MockRestServiceServer couponServer;
	private ProductRestController controller;

	@BeforeEach
	void setUp() {
		registry = new SimpleMeterRegistry();
		restTemplate = new RestTemplate();
		couponServer = MockRestServiceServer.createServer(restTemplate);
		controller = new ProductRestController(repo, restTemplate, new ProductMetrics(registry), COUPON_URL);
	}

	@Test
	void createRecordsSuccessOutcomeAndDatabaseTime() {
		Product product = product("SAVE10", "100");
		couponServer.expect(requestTo(COUPON_URL + "SAVE10"))
				.andRespond(withSuccess("{\"code\":\"SAVE10\",\"discount\":10}", MediaType.APPLICATION_JSON));
		when(repo.save(product)).thenReturn(product);

		Product saved = controller.create(product);

		couponServer.verify();
		assertThat(saved.getPrice()).isEqualByComparingTo("90");
		assertThat(registry.get(ProductMetrics.OPERATION).tag("status", "success").tag("operation", "create")
				.counter().count()).isEqualTo(1);
		assertThat(registry.get(ProductMetrics.DB_OPERATION_DURATION).tag("operation", "save").tag("status", "success")
				.timer().count()).isEqualTo(1);
		assertThat(registry.get(ProductMetrics.COUPON_CLIENT_DURATION).tag("status", "success").timer().count())
				.isEqualTo(1);
		assertThat(registry.find(ProductMetrics.COUPON_CLIENT_ERRORS).counters()).isEmpty();
		assertTagsExcludeCouponCode("SAVE10");
	}

	@Test
	void createRecordsCouponFailureWithoutTouchingTheDatabase() {
		couponServer.expect(requestTo(COUPON_URL + "SAVE10")).andRespond(withServerError());

		assertThatThrownBy(() -> controller.create(product("SAVE10", "100")))
				.isInstanceOf(RestClientException.class);

		couponServer.verify();
		verify(repo, never()).save(any());
		assertThat(registry.get(ProductMetrics.COUPON_CLIENT_ERRORS).counter().count()).isEqualTo(1);
		assertThat(registry.get(ProductMetrics.COUPON_CLIENT_DURATION).tag("status", "error").timer().count())
				.isEqualTo(1);
		assertThat(registry.get(ProductMetrics.OPERATION).tag("status", "error").counter().count()).isEqualTo(1);
		assertThat(registry.get(ProductMetrics.OPERATION).tag("status", "error").counter().getId().getTag("exception"))
				.isNotEqualTo("none");
		assertThat(registry.find(ProductMetrics.DB_OPERATION_DURATION).timers()).isEmpty();
	}

	@Test
	void createRecordsDatabaseFailureAfterASuccessfulCouponCall() {
		Product product = product("SAVE10", "100");
		couponServer.expect(requestTo(COUPON_URL + "SAVE10"))
				.andRespond(withSuccess("{\"code\":\"SAVE10\",\"discount\":10}", MediaType.APPLICATION_JSON));
		when(repo.save(product)).thenThrow(new IllegalStateException("db"));

		assertThatThrownBy(() -> controller.create(product)).isInstanceOf(IllegalStateException.class);

		assertThat(registry.get(ProductMetrics.COUPON_CLIENT_DURATION).tag("status", "success").timer().count())
				.isEqualTo(1);
		assertThat(registry.find(ProductMetrics.COUPON_CLIENT_ERRORS).counters()).isEmpty();
		assertThat(registry.get(ProductMetrics.DB_OPERATION_DURATION).tag("status", "error")
				.tag("exception", "IllegalStateException").timer().count()).isEqualTo(1);
		assertThat(registry.get(ProductMetrics.OPERATION).tag("status", "error")
				.tag("exception", "IllegalStateException").counter().count()).isEqualTo(1);
	}

	@Test
	void createRecordsAMissingCouponAsAClientError() {
		couponServer.expect(requestTo(COUPON_URL + "SAVE10"))
				.andRespond(withSuccess("null", MediaType.APPLICATION_JSON));

		assertThatThrownBy(() -> controller.create(product("SAVE10", "100")))
				.isInstanceOf(CouponClientException.class);

		verify(repo, never()).save(any());
		assertThat(registry.get(ProductMetrics.COUPON_CLIENT_ERRORS).tag("exception", "CouponClientException")
				.counter().count()).isEqualTo(1);
		assertThat(registry.get(ProductMetrics.COUPON_CLIENT_DURATION).tag("status", "error").timer().count())
				.isEqualTo(1);
		assertThat(registry.find(ProductMetrics.DB_OPERATION_DURATION).timers()).isEmpty();
	}

	private void assertTagsExcludeCouponCode(String couponCode) {
		for (Meter meter : registry.getMeters()) {
			for (Tag tag : meter.getId().getTags()) {
				assertThat(tag.getValue()).isNotEqualTo(couponCode);
			}
		}
	}

	private static Product product(String couponCode, String price) {
		Product product = new Product();
		product.setName("notebook");
		product.setCouponCode(couponCode);
		product.setPrice(new BigDecimal(price));
		return product;
	}
}
