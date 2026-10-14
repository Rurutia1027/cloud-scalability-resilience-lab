package com.tus.coupon.metrics;

import java.time.Duration;
import java.util.function.Supplier;

import com.tus.coupon.model.Coupon;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;

/**
 * Meters for the coupon lookup. Incoming HTTP volume and latency stay on
 * Spring Boot's {@code http.server.requests} timer.
 *
 * <p>Meters are registered once per label set. Labels are {@code operation},
 * {@code status}, and {@code exception}. Coupon codes are not labels.
 */
public class CouponMetrics {

	public static final String LOOKUP = "coupon.lookup";
	public static final String LOOKUP_ERRORS = "coupon.lookup.errors";
	public static final String LOOKUP_DURATION = "coupon.lookup.duration";

	static final String NOT_FOUND = "NotFound";

	private static final Duration[] LOOKUP_SLOS = {
			Duration.ofMillis(10),
			Duration.ofMillis(50),
			Duration.ofMillis(100),
			Duration.ofMillis(200),
			Duration.ofMillis(500),
			Duration.ofSeconds(1)
	};

	private final MeterRegistry registry;

	public CouponMetrics(MeterRegistry registry) {
		this.registry = registry;
	}

	public Coupon recordLookup(Supplier<Coupon> call) {
		Timer.Sample sample = Timer.start(registry);
		String status = "success";
		String exception = "none";
		try {
			Coupon coupon = call.get();
			if (coupon == null) {
				status = "not_found";
				exception = NOT_FOUND;
				incrementErrors("findByCode", exception);
			}
			return coupon;
		} catch (RuntimeException ex) {
			status = "error";
			exception = ex.getClass().getSimpleName();
			incrementErrors("findByCode", exception);
			throw ex;
		} finally {
			Counter.builder(LOOKUP)
					.description("Coupon lookup attempts")
					.tags("operation", "findByCode", "status", status, "exception", exception)
					.register(registry)
					.increment();
			sample.stop(timer("findByCode", status, exception));
		}
	}

	private void incrementErrors(String operation, String exception) {
		Counter.builder(LOOKUP_ERRORS)
				.description("Failed coupon lookups")
				.tags("operation", operation, "exception", exception)
				.register(registry)
				.increment();
	}

	private Timer timer(String operation, String status, String exception) {
		return Timer.builder(LOOKUP_DURATION)
				.description("Time spent looking up a coupon")
				.tags("operation", operation, "status", status, "exception", exception)
				.publishPercentileHistogram()
				.serviceLevelObjectives(LOOKUP_SLOS)
				.register(registry);
	}
}
