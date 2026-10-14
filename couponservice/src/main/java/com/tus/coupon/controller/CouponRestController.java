package com.tus.coupon.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.tus.coupon.metrics.CouponMetrics;
import com.tus.coupon.model.Coupon;
import com.tus.coupon.repo.CouponRepo;

@RestController
@RequestMapping("/couponapi")
public class CouponRestController {

	private final CouponRepo repo;
	private final CouponMetrics metrics;

	public CouponRestController(CouponRepo repo, CouponMetrics metrics) {
		this.repo = repo;
		this.metrics = metrics;
	}

	@PostMapping(value = "/coupons")
	public ResponseEntity<Coupon> create(@RequestBody Coupon coupon) {
		return new ResponseEntity<>(repo.save(coupon), HttpStatus.OK);
	}

	@GetMapping("/coupons/{code}")
	Coupon getCouponByCouponCode(@PathVariable String code) {
		System.out.println(code);
		return metrics.recordLookup(() -> repo.findByCode(code));
	}

	@GetMapping(value = "/coupons")
	public List<Coupon> getAllCoupons() {
		return repo.findAll();
	}
}
