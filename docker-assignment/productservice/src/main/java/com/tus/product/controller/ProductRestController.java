package com.tus.product.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

import com.tus.product.dto.Coupon;
import com.tus.product.metrics.ProductMetrics;
import com.tus.product.model.Product;
import com.tus.product.repos.ProductRepo;

@RestController
@RequestMapping("/productapi")
public class ProductRestController {

	private final ProductRepo repo;
	private final RestTemplate restTemplate;
	private final ProductMetrics metrics;
	private final String couponServiceURL;

	public ProductRestController(ProductRepo repo, RestTemplate restTemplate, ProductMetrics metrics,
			@Value("${couponService.url}") String couponServiceURL) {
		this.repo = repo;
		this.restTemplate = restTemplate;
		this.metrics = metrics;
		this.couponServiceURL = couponServiceURL;
	}

	@RequestMapping(value = "/products", method = RequestMethod.POST)
	public Product create(@RequestBody Product product) {
		RuntimeException failure = null;
		try {
			Coupon coupon = metrics.recordCouponClient(() -> restTemplate.getForObject(
					couponServiceURL + "{code}", Coupon.class, product.getCouponCode()));
			product.setPrice(product.getPrice().subtract(coupon.getDiscount()));
			return metrics.recordDatabase("save", () -> repo.save(product));
		} catch (RuntimeException ex) {
			failure = ex;
			throw ex;
		} finally {
			metrics.recordOperation("create", failure == null, failure);
		}
	}

	@GetMapping(value = "/products")
	public List<Product> getAllProducts() {
		return repo.findAll();
	}

}
