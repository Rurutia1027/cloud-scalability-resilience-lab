package com.tus.product.metrics;

import java.time.Duration;
import java.util.function.Supplier;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;

/**
 * Meters for the product create path. HTTP throughput and latency stay on
 * Spring Boot's {@code http.server.requests} timer. These meters cover the
 * coupon call, the MySQL write, and the business outcome.
 *
 * <p>Meters are registered once per label set. The registry caches them, so a
 * request does not create a new meter. Labels are {@code operation},
 * {@code status}, and {@code exception}.
 */
public class ProductMetrics {

	public static final String COUPON_CLIENT_DURATION = "coupon.client.request.duration";
	public static final String COUPON_CLIENT_ERRORS = "coupon.client.errors";
	public static final String DB_OPERATION_DURATION = "product.db.operation.duration";
	public static final String OPERATION = "product.operation";

	private static final Duration[] CLIENT_SLOS = {
			Duration.ofMillis(50),
			Duration.ofMillis(100),
			Duration.ofMillis(200),
			Duration.ofMillis(500),
			Duration.ofSeconds(1)
	};

	private static final Duration[] DB_SLOS = {
			Duration.ofMillis(10),
			Duration.ofMillis(50),
			Duration.ofMillis(100),
			Duration.ofMillis(200),
			Duration.ofMillis(500),
			Duration.ofSeconds(1)
	};

	private final MeterRegistry registry;

	public ProductMetrics(MeterRegistry registry) {
		this.registry = registry;
	}

	public <T> T recordCouponClient(Supplier<T> call) {
		Timer.Sample sample = Timer.start(registry);
		String status = "success";
		String exception = "none";
		try {
			T result = call.get();
			if (result == null) {
				status = "error";
				exception = CouponClientException.class.getSimpleName();
				incrementErrors("getCoupon", exception);
				throw new CouponClientException("Coupon service returned no coupon");
			}
			return result;
		} catch (CouponClientException ex) {
			throw ex;
		} catch (RuntimeException ex) {
			status = "error";
			exception = ex.getClass().getSimpleName();
			incrementErrors("getCoupon", exception);
			throw ex;
		} finally {
			sample.stop(timer(COUPON_CLIENT_DURATION,
					"Time spent calling couponservice from productservice",
					"getCoupon", status, exception, CLIENT_SLOS));
		}
	}

	public <T> T recordDatabase(String operation, Supplier<T> call) {
		Timer.Sample sample = Timer.start(registry);
		String status = "success";
		String exception = "none";
		try {
			return call.get();
		} catch (RuntimeException ex) {
			status = "error";
			exception = ex.getClass().getSimpleName();
			throw ex;
		} finally {
			sample.stop(timer(DB_OPERATION_DURATION,
					"Time spent in productservice MySQL operations",
					operation, status, exception, DB_SLOS));
		}
	}

	public void recordOperation(String operation, boolean success, RuntimeException failure) {
		String status = success ? "success" : "error";
		String exception = failure == null ? "none" : failure.getClass().getSimpleName();
		Counter.builder(OPERATION)
				.description("Outcomes of productservice business operations")
				.tags("operation", operation, "status", status, "exception", exception)
				.register(registry)
				.increment();
	}

	private void incrementErrors(String operation, String exception) {
		Counter.builder(COUPON_CLIENT_ERRORS)
				.description("Failed calls from productservice to couponservice")
				.tags("operation", operation, "exception", exception)
				.register(registry)
				.increment();
	}

	private Timer timer(String name, String description, String operation, String status, String exception,
			Duration[] slos) {
		return Timer.builder(name)
				.description(description)
				.tags("operation", operation, "status", status, "exception", exception)
				.publishPercentileHistogram()
				.serviceLevelObjectives(slos)
				.register(registry);
	}
}
