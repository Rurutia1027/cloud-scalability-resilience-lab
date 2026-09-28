package com.tus.coupon.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;
import com.tus.coupon
.model.Coupon;
import com.tus.coupon.repo.CouponRepo;


@RestController
@RequestMapping("/couponapi")
public class CouponRestController {
//comment for version control
	@Autowired
	CouponRepo repo;
	
	//this is called constructor based injection.
	// you can now use normal mocks to test
	/*
	 * public CouponRestController(CouponRepo repo) { this.repo=repo; }
	 */
	//setter injection
//	@Autowired
//	public void setRepo(CouponRepo repo) {
//		this.repo=repo;
//	}
	
	@PostMapping(value = "/coupons")
	public ResponseEntity<Coupon> create(@RequestBody Coupon coupon) {
		//return repo.save(coupon);
		return new ResponseEntity<>(repo.save(coupon), HttpStatus.OK);
	}
	
	@GetMapping("/coupons/{code}")
	Coupon getCouponByCouponCode(@PathVariable String code) {
		System.out.println(code);
			return repo.findByCode(code);
	}
	
	
	@GetMapping(value = "/coupons")
	public List<Coupon> getAllCoupons() {
		return repo.findAll();

	}
}
