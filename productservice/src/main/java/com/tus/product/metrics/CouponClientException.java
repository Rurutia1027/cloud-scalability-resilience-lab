package com.tus.product.metrics;

/**
 * The coupon call returned no coupon. The exception type is a bounded metric label.
 */
public class CouponClientException extends RuntimeException {

	public CouponClientException(String message) {
		super(message);
	}
}
